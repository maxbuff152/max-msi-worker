"""Exercise the actual embedded Bash with isolated homes and fake external tools."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BOOT = (ROOT / 'bootstrap-max-msi.ps1').read_text()
PAYLOAD = BOOT.split("$bash = @'\n", 1)[1].split("\n'@", 1)[0]


class Entrypoints(unittest.TestCase):
    def run_setup(self, existing=None, **overrides):
        with tempfile.TemporaryDirectory(prefix='msi home ') as tmp:
            home = Path(tmp)
            bins = home / '.local/bin'
            bins.mkdir(parents=True)
            log = home / 'commands'
            launcher = '#!/bin/bash\nprintf "launch:%s\\n" "$0" >> "$LOG"\n'
            if existing:
                repo = home / existing
                repo.mkdir(parents=True)
                (repo / '.git').write_text('gitdir: fixture\n')  # worktree supported
                (repo / 'start-max-msi.sh').write_text(launcher)
            if overrides.pop('occupied', False):
                (home / 'Projects/active/max-msi-worker').mkdir(parents=True)
            git = '''#!/bin/bash
printf 'git:%s\\n' "$*" >> "$LOG"
if [[ "$1" == clone ]]; then
  [[ "${FAIL_CLONE:-0}" == 0 ]] || exit 1
  mkdir -p "$3/.git"
  printf '#!/bin/bash\\nprintf "launch:%%s\\\\n" "$0" >> "$LOG"\\n' > "$3/start-max-msi.sh"
  exit 0
fi
case "$3" in
  remote) echo "${ORIGIN:-https://github.com/maxbuff152/max-msi-worker.git}" ;;
  status) printf '%s' "${DIRTY:-}" ;;
  symbolic-ref) echo "${BRANCH:-main}" ;;
  fetch) exit "${FAIL_FETCH:-0}" ;;
  merge) exit "${FAIL_MERGE:-0}" ;;
esac
'''
            for name, content in {'git': git, 'tmux': '#!/bin/bash\nexit 0\n',
                                  'agent': '#!/bin/bash\nprintf "agent:%s\\n" "$*" >> "$LOG"\nexit 0\n'}.items():
                p = bins / name
                p.write_text(content)
                p.chmod(0o755)
            env = dict(os.environ, HOME=str(home), PATH=str(bins)+':/usr/bin:/bin', LOG=str(log), **overrides)
            result = subprocess.run(['bash', '-c', PAYLOAD], env=env, text=True, capture_output=True)
            commands = log.read_text() if log.exists() else ''
            alias = home / 'Projects/active/max-msi-worker'
            return result, commands, alias.is_symlink()

    def test_fresh_install_uses_canonical_launcher(self):
        result, commands, _ = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Projects/active/max-msi-worker', commands)
        self.assertIn('launch:', commands)
        self.assertNotIn('worker start', commands)

    def test_existing_canonical_fast_forward(self):
        result, commands, alias = self.run_setup('Projects/active/max-msi-worker')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('merge --ff-only FETCH_HEAD', commands)
        self.assertNotIn('git:clone', commands)
        self.assertFalse(alias)

    def test_legacy_paths_remain_in_place(self):
        for path in ('projects/max-msi-worker', 'Projects/max-msi-worker', 'projects/active/max-msi-worker'):
            with self.subTest(path=path):
                result, commands, alias = self.run_setup(path)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(alias)
                self.assertIn(path+'/start-max-msi.sh', commands)

    def test_unsafe_or_failed_updates_never_launch(self):
        for opts in ({'DIRTY': ' M README.md'}, {'BRANCH': 'feature'}, {'ORIGIN': 'https://example.com/other.git'},
                     {'FAIL_FETCH': '1'}, {'FAIL_MERGE': '1'}, {'occupied': True}):
            with self.subTest(opts=opts):
                result, commands, _ = self.run_setup('projects/max-msi-worker', **opts)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('launch:', commands)
        result, commands, _ = self.run_setup(FAIL_CLONE='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('launch:', commands)

    def test_windows_commands_and_retired_entrypoints(self):
        cmd = (ROOT / 'START-MAX-MSI.cmd').read_text()
        self.assertIn('-File "%~dp0bootstrap-max-msi.ps1"', cmd)
        self.assertIn('~/Projects/active/max-msi-worker/start-max-msi.sh', cmd)
        self.assertNotIn('~/projects/', cmd)
        self.assertIn('source <(echo $encoded | base64 -d)', BOOT)
        self.assertNotIn('Start-Process', BOOT)
        auto = (ROOT / 'install-autostart.ps1').read_text()
        self.assertIn('Disable-ScheduledTask', auto)
        self.assertIn('Stop-ScheduledTask', auto)
        self.assertNotIn('Register-ScheduledTask', auto)
        self.assertNotIn('agent worker start', auto)
        fix = (ROOT / 'fix-windows-worker.ps1').read_text()
        self.assertIn('throw ', fix)
        self.assertNotIn('agent worker start', fix)

    def test_shared_launcher_passes_three_dirs_and_deduplicates(self):
        with tempfile.TemporaryDirectory(prefix='worker home ') as tmp:
            home = Path(tmp)
            bins = home / '.local/bin'
            bins.mkdir(parents=True)
            for repo in ('SellersFirstWebsite', 'max-msi-worker', 'messages-loop'):
                (home / 'Projects/active' / repo).mkdir(parents=True)
            for name, content in {
                'agent': '#!/bin/bash\nexit 0\n',
                'sleep': '#!/bin/bash\nexit 0\n',
                'tmux': '#!/bin/bash\nprintf "%s\\n" "$*" >> "$LOG"\n[[ "$1" != has-session ]] || exit "${EXISTS:-1}"\n',
            }.items():
                p = bins / name
                p.write_text(content)
                p.chmod(0o755)
            env = dict(os.environ, HOME=str(home), LOG=str(home/'log'), PATH=str(bins)+':/usr/bin:/bin')
            result = subprocess.run(['bash', str(ROOT/'start-max-msi.sh')], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            text = (home/'log').read_text()
            command = text.split('bash -lc ', 1)[1].split('\ncapture-pane', 1)[0]
            worker = bins/'agent'
            worker.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$LOG"\n')
            subprocess.run(['bash', '-c', command], env=env, check=True)
            args = (home/'log').read_text().splitlines()
            self.assertEqual(args[:4], ['worker', 'start', '--name', 'Max-MSI'])
            self.assertEqual(args.count('--worker-dir'), 3)
            for repo in ('SellersFirstWebsite', 'max-msi-worker', 'messages-loop'):
                self.assertIn(str(home/'Projects/active'/repo), args)
            (home/'log').write_text('')
            subprocess.run(['bash', str(ROOT/'start-max-msi.sh')], env=dict(env, EXISTS='0'), check=True, capture_output=True)
            self.assertNotIn('new-session', (home/'log').read_text())


if __name__ == '__main__':
    unittest.main()
