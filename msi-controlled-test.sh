#!/usr/bin/env bash
# Controlled before/after health + speed checks for Max-MSI (WSL Ubuntu).
# NEVER moves, renames, or deletes project checkouts.
#
# Usage:
#   bash msi-controlled-test.sh before
#   bash msi-controlled-test.sh after
#   bash msi-controlled-test.sh compare
#   bash msi-controlled-test.sh all   # before → ensure → after → compare
#
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

PHASE="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${MSI_BENCH_DIR:-$HOME/.cursor/max-msi-bench}"
mkdir -p "$REPORT_DIR"

# shellcheck source=/dev/null
source "$ROOT/msi-worker-dirs.sh"

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()[:-1] if False else sys.argv[1]))' "$1"
}

median_ms() {
  # stdin: one float ms per line → median printed
  sort -n | awk '
    { a[NR]=$1 }
    END {
      if (NR==0) { print "null"; exit }
      if (NR%2==1) print a[(NR+1)/2]
      else print (a[NR/2]+a[NR/2+1])/2
    }'
}

time_ms() {
  local start end
  start=$(date +%s%N)
  "$@" >/dev/null 2>&1 || true
  end=$(date +%s%N)
  awk -v s="$start" -v e="$end" 'BEGIN{printf "%.3f", (e-s)/1000000}'
}

time_median_cmd() {
  local n="${1:-3}"; shift
  local i out
  out=""
  for i in $(seq 1 "$n"); do
    out+="$(time_ms "$@")"$'\n'
  done
  printf '%s' "$out" | median_ms
}

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

fingerprint() {
  local os_name fs_type home_fs
  os_name="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
  home_fs="$(df -T "$HOME" 2>/dev/null | awk 'NR==2{print $2}')"
  fs_type="${home_fs:-unknown}"
  cat <<EOF
{
  "hostname": $(json_escape "$(hostname 2>/dev/null || echo unknown)"),
  "uname": $(json_escape "$(uname -a)"),
  "os": $(json_escape "$os_name"),
  "is_wsl": $(is_wsl && echo true || echo false),
  "wsl_distro": $(json_escape "${WSL_DISTRO_NAME:-}"),
  "home_fstype": $(json_escape "$fs_type"),
  "home": $(json_escape "$HOME"),
  "pwd": $(json_escape "$(pwd)"),
  "path_has_mnt_c": $([[ "$PWD" == /mnt/c/* || "$ROOT" == /mnt/c/* ]] && echo true || echo false)
}
EOF
}

agent_health() {
  local version whoami debug_rc debug_snip has_agent
  has_agent=false
  version=""
  whoami=""
  debug_rc=null
  debug_snip=""
  if command -v agent >/dev/null 2>&1; then
    has_agent=true
    version="$(agent --version 2>&1 | head -5 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
    whoami="$(agent whoami 2>&1 | head -5 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' || true)"
    set +e
    debug_snip="$(agent worker debug 2>&1 | head -40)"
    debug_rc=$?
    set -e
  fi
  cat <<EOF
{
  "agent_on_path": $has_agent,
  "version": $(json_escape "$version"),
  "whoami": $(json_escape "$whoami"),
  "worker_debug_exit": $debug_rc,
  "worker_debug_head": $(json_escape "$debug_snip")
}
EOF
}

dir_speeds() {
  local d name status_ms ls_ms under_mnt bugs
  echo '['
  local first=1
  for d in "${MSI_WORKER_DIRS[@]}"; do
    name="$(basename "$d")"
    status_ms=null
    ls_ms=null
    under_mnt=false
    bugs=()
    [[ "$d" == /mnt/c/* ]] && under_mnt=true && bugs+=("path_on_mnt_c")
    if [[ -d "$d" ]]; then
      ls_ms="$(time_ms ls -la "$d")"
      if [[ -d "$d/.git" ]]; then
        status_ms="$(time_median_cmd 3 git -C "$d" status --porcelain)"
      else
        bugs+=("missing_git")
      fi
    else
      bugs+=("missing_dir")
    fi
    local bug_json='[]'
    if [[ ${#bugs[@]} -gt 0 ]]; then
      bug_json='['
      local b firstb=1
      for b in "${bugs[@]}"; do
        [[ $firstb -eq 1 ]] || bug_json+=','
        firstb=0
        bug_json+=$(json_escape "$b")
      done
      bug_json+=']'
    fi
    [[ $first -eq 1 ]] || echo ','
    first=0
    cat <<EOF
{
  "name": $(json_escape "$name"),
  "path": $(json_escape "$d"),
  "exists": $([[ -d "$d" ]] && echo true || echo false),
  "under_mnt_c": $under_mnt,
  "git_status_median_ms": $status_ms,
  "ls_ms": $ls_ms,
  "bugs": $bug_json
}
EOF
  done
  echo ']'
}

windows_abi_smell() {
  # Heuristic: Windows worker crash strings in recent logs / debug — informational only.
  local hits=0
  if command -v agent >/dev/null 2>&1; then
    if agent worker debug 2>&1 | grep -qiE 'better-sqlite3|NODE_MODULE_VERSION|127 vs 137|was compiled against'; then
      hits=1
    fi
  fi
  # Native Windows agent path should not be what we run inside WSL.
  if uname -s | grep -qi mingw; then
    hits=1
  fi
  echo "$hits"
}

run_phase() {
  local label="$1"
  local out="$REPORT_DIR/${label}.json"
  local ts bugs_list
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  bugs_list=()

  is_wsl || bugs_list+=("not_wsl")
  command -v agent >/dev/null 2>&1 || bugs_list+=("agent_cli_missing")
  [[ "$(windows_abi_smell)" == "1" ]] && bugs_list+=("windows_abi_or_native_smell")

  local bug_json='[]'
  if [[ ${#bugs_list[@]} -gt 0 ]]; then
    bug_json='['
    local b firstb=1
    for b in "${bugs_list[@]}"; do
      [[ $firstb -eq 1 ]] || bug_json+=','
      firstb=0
      bug_json+=$(json_escape "$b")
    done
    bug_json+=']'
  fi

  local fp health speeds
  fp="$(fingerprint)"
  health="$(agent_health)"
  speeds="$(dir_speeds)"

  cat >"$out" <<EOF
{
  "phase": $(json_escape "$label"),
  "timestamp": $(json_escape "$ts"),
  "fingerprint": $fp,
  "agent": $health,
  "worker_dirs": $speeds,
  "bugs": $bug_json
}
EOF
  echo "Wrote $out"
  python3 - <<'PY' "$out"
import json,sys
p=sys.argv[1]
d=json.load(open(p))
print(f"=== {d['phase']} @ {d['timestamp']} ===")
fp=d['fingerprint']
print(f"host={fp['hostname']} wsl={fp['is_wsl']} fstype={fp['home_fstype']}")
print(f"agent_on_path={d['agent']['agent_on_path']} version={d['agent']['version'][:80]}")
print(f"bugs={d['bugs']}")
for w in d['worker_dirs']:
    print(f"  {w['name']}: exists={w['exists']} mnt_c={w['under_mnt_c']} git_status_ms={w['git_status_median_ms']} ls_ms={w['ls_ms']} bugs={w['bugs']}")
PY
}

compare_phases() {
  local before="$REPORT_DIR/before.json"
  local after="$REPORT_DIR/after.json"
  local out="$REPORT_DIR/compare.json"
  if [[ ! -f "$before" || ! -f "$after" ]]; then
    echo "Need both before.json and after.json in $REPORT_DIR" >&2
    exit 1
  fi
  python3 - <<'PY' "$before" "$after" "$out"
import json,sys
b=json.load(open(sys.argv[1]))
a=json.load(open(sys.argv[2]))
out=sys.argv[3]

def idx(report):
    return {w['name']: w for w in report.get('worker_dirs', [])}

bi, ai = idx(b), idx(a)
names=sorted(set(bi)|set(ai))
rows=[]
for n in names:
    bw, aw = bi.get(n), ai.get(n)
    row={"name": n}
    for key in ("git_status_median_ms","ls_ms"):
        bv = None if not bw else bw.get(key)
        av = None if not aw else aw.get(key)
        row[key+"_before"]=bv
        row[key+"_after"]=av
        if isinstance(bv,(int,float)) and isinstance(av,(int,float)) and bv>0:
            row[key+"_delta_ms"]=round(av-bv,3)
            row[key+"_speedup_x"]=round(bv/av,3) if av else None
        else:
            row[key+"_delta_ms"]=None
            row[key+"_speedup_x"]=None
    row["bugs_before"]= (bw or {}).get("bugs",[])
    row["bugs_after"]= (aw or {}).get("bugs",[])
    rows.append(row)

summary={
  "before_bugs": b.get("bugs",[]),
  "after_bugs": a.get("bugs",[]),
  "before_wsl": b.get("fingerprint",{}).get("is_wsl"),
  "after_wsl": a.get("fingerprint",{}).get("is_wsl"),
  "before_agent": b.get("agent",{}).get("agent_on_path"),
  "after_agent": a.get("agent",{}).get("agent_on_path"),
  "dirs": rows,
}
json.dump(summary, open(out,"w"), indent=2)
print(json.dumps(summary, indent=2))
print(f"Wrote {out}")
PY
}

ensure_linux_worker_path() {
  # Install/refresh Linux Agent CLI only. Does not move repos.
  echo "==> Ensuring Linux Cursor Agent CLI (circumvents Windows better-sqlite3 ABI)"
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl missing" >&2
    exit 1
  fi
  curl https://cursor.com/install -fsS | bash
  export PATH="$HOME/.local/bin:$PATH"
  command -v agent
  agent --version || true

  mkdir -p "$HOME/Projects/active" "$HOME/bin"
  # Install helper copies without touching project trees
  cp -f "$ROOT/msi-worker-dirs.sh" "$HOME/bin/msi-worker-dirs.sh"
  cp -f "$ROOT/msi-worker-status" "$HOME/bin/msi-worker-status"
  chmod +x "$HOME/bin/msi-worker-dirs.sh" "$HOME/bin/msi-worker-status"

  # Clone only if missing — never move existing checkouts
  local name url dest
  declare -A REPOS=(
    [max-msi-worker]="https://github.com/maxbuff152/max-msi-worker.git"
    [SellersFirstWebsite]="https://github.com/maxbuff152/SellersFirstWebsite.git"
    [messages-loop]="https://github.com/maxbuff152/messages-loop.git"
  )
  # Refresh MSI_WORKER_DIRS after helpers installed
  # shellcheck source=/dev/null
  source "$HOME/bin/msi-worker-dirs.sh"

  for name in "${!REPOS[@]}"; do
    url="${REPOS[$name]}"
    dest="$(msi_resolve_worker_dir "$name")"
    if [[ -d "$dest/.git" ]]; then
      echo "keep in place: $dest"
    elif [[ -d "$dest" ]]; then
      echo "keep in place (no .git yet): $dest"
    else
      # Prefer canonical active path for new clones only
      dest="$HOME/Projects/active/$name"
      if [[ ! -d "$dest/.git" ]]; then
        echo "clone (missing only): $dest"
        git clone "$url" "$dest"
      fi
    fi
    if [[ "$dest" == /mnt/c/* ]]; then
      echo "WARN: $dest is on /mnt/c — slow & fragile. Leave it; prefer a Linux-disk copy later." >&2
    fi
  done

  if ! agent whoami >/dev/null 2>&1; then
    echo "Not logged in. Run: agent login (same account as iPhone), then re-run."
    agent login || true
  fi
}

restart_max_msi_worker() {
  # Safe restart only when explicitly requested via 'all' or 'apply'
  export PATH="$HOME/.local/bin:$PATH"
  export AGENT_CLI_CREDENTIAL_STORE=file
  local starter
  starter="$(msi_resolve_worker_dir max-msi-worker)/start-max-msi.sh"
  if [[ ! -x "$starter" && -f "$ROOT/start-max-msi.sh" ]]; then
    starter="$ROOT/start-max-msi.sh"
  fi
  # Stop prior tmux session if present (does not touch project files)
  if tmux has-session -t max-msi-worker 2>/dev/null; then
    echo "==> Stopping existing tmux session max-msi-worker"
    tmux kill-session -t max-msi-worker || true
    sleep 1
  fi
  bash "$starter"
}

case "$PHASE" in
  before|after)
    run_phase "$PHASE"
    ;;
  compare)
    compare_phases
    ;;
  ensure)
    ensure_linux_worker_path
    ;;
  apply)
    ensure_linux_worker_path
    restart_max_msi_worker
    ;;
  all)
    run_phase before
    ensure_linux_worker_path
    restart_max_msi_worker
    sleep 3
    run_phase after
    compare_phases
    ;;
  *)
    cat <<EOF
Usage: $0 {before|after|compare|ensure|apply|all}

  before   Record health + speed baseline (no changes)
  ensure   Install Linux agent CLI + helpers; clone missing repos only
  apply    ensure + restart Max-MSI worker in tmux
  after    Record post-change metrics
  compare  Diff before.json vs after.json
  all      before → ensure → restart → after → compare

Keeps all existing checkouts in place. Never uses Windows-native agent.
EOF
    exit 1
    ;;
esac
