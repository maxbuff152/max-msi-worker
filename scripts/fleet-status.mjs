#!/usr/bin/env node
/**
 * Publish soft fleet health for Command Desk (`internal:fleet-status`).
 *
 * Probes local MSI worker only by default. Optional soft SSH pings for Mac / Lenovo
 * when FLEET_SSH_PROBES=1 (never stores secrets).
 *
 * Usage:
 *   node scripts/fleet-status.mjs
 *   node scripts/fleet-status.mjs --publish
 */

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, ".cache", "fleet-status");

const FLEET_NODE_IDS = ["msi", "mac", "lenovo"];
const FLEET_NODE_META = {
  msi: { label: "MSI Brain", role: "Code · git · orchestrate" },
  mac: { label: "Mac Messages", role: "iMessage · Continuity" },
  lenovo: { label: "Lenovo Matrix", role: "HAR · comps · heavy web" },
};
const SECRETISH = /secret|token|password|passwd|api[_-]?key|authorization|cookie|bearer|private[_-]?key|email|@/i;

function hasFlag(flag) {
  return process.argv.includes(flag);
}

function isoNow() {
  return new Date().toISOString();
}

function sanitizeDetail(value) {
  const text = String(value == null ? "" : value).replace(/\s+/g, " ").trim().slice(0, 120);
  if (!text || SECRETISH.test(text)) return null;
  return text;
}

function deriveStatus(lastSeen, nowMs = Date.now()) {
  if (!lastSeen) return "unknown";
  const age = nowMs - new Date(lastSeen).getTime();
  if (!Number.isFinite(age) || age < 0) return "unknown";
  if (age <= 3 * 60 * 1000) return "online";
  if (age <= 20 * 60 * 1000) return "stale";
  return "offline";
}

function probeMsi() {
  const now = isoNow();
  // Live wire is Max-MSI / max-msi-worker. Accept legacy MSI / msi-workers as healthy too.
  const tmuxPrimary = spawnSync("tmux", ["has-session", "-t", "max-msi-worker"], { encoding: "utf8" });
  const tmuxLegacy = spawnSync("tmux", ["has-session", "-t", "msi-workers"], { encoding: "utf8" });
  const workerPrimary = spawnSync("pgrep", ["-af", "worker start --name Max-MSI"], { encoding: "utf8" });
  const workerLegacy = spawnSync("pgrep", ["-af", "worker start --name MSI"], { encoding: "utf8" });
  const tmuxOk = tmuxPrimary.status === 0 || tmuxLegacy.status === 0;
  const workerOk =
    (workerPrimary.status === 0 && Boolean((workerPrimary.stdout || "").trim())) ||
    (workerLegacy.status === 0 && Boolean((workerLegacy.stdout || "").trim()));
  if (tmuxOk || workerOk) {
    return {
      id: "msi",
      lastSeen: now,
      detail: tmuxOk && workerOk ? "tmux + worker" : tmuxOk ? "tmux up" : "worker up",
    };
  }
  return { id: "msi", lastSeen: null, detail: "no Max-MSI worker session", status: "offline" };
}

function softSshProbe(host, id) {
  const res = spawnSync(
    "ssh",
    ["-o", "BatchMode=yes", "-o", "ConnectTimeout=3", host, "echo ok"],
    { encoding: "utf8" },
  );
  if (res.status === 0 && /ok/.test(res.stdout || "")) {
    return { id, lastSeen: isoNow(), detail: "ssh reachable" };
  }
  return { id, lastSeen: null, status: "unknown", detail: "ssh not probed or unreachable" };
}

function normalizePayload(nodes, generatedAt = isoNow()) {
  const byId = Object.fromEntries(nodes.filter(Boolean).map((n) => [n.id, n]));
  const nowMs = Date.parse(generatedAt) || Date.now();
  const normalized = FLEET_NODE_IDS.map((id) => {
    const raw = byId[id] || {};
    const lastSeen = raw.lastSeen || null;
    const status = raw.status === "unknown" && !lastSeen ? "unknown" : deriveStatus(lastSeen, nowMs);
    return {
      id,
      label: FLEET_NODE_META[id].label,
      role: FLEET_NODE_META[id].role,
      status: lastSeen ? status : raw.status || "unknown",
      lastSeen,
      detail: sanitizeDetail(raw.detail),
    };
  });
  return {
    generatedAt,
    nodes: normalized,
    summary: {
      online: normalized.filter((n) => n.status === "online").length,
      total: normalized.length,
      allKnown: normalized.every((n) => n.status !== "unknown"),
    },
  };
}

async function publishKey(baseUrl, secret, key, body) {
  const res = await fetch(`${baseUrl.replace(/\/$/, "")}/api/board-publish`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${secret}`,
      "Content-Type": "application/json",
      "X-Board-Key": key,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`publish ${key} failed: ${res.status} ${await res.text()}`);
  }
  return res.json();
}

async function main() {
  const nodes = [probeMsi()];
  if (process.env.FLEET_SSH_PROBES === "1") {
    nodes.push(softSshProbe(process.env.FLEET_MAC_HOST || "macbook", "mac"));
    nodes.push(softSshProbe(process.env.FLEET_LENOVO_HOST || "logan-lenovo", "lenovo"));
  } else {
    nodes.push({ id: "mac", lastSeen: null, status: "unknown", detail: "enable FLEET_SSH_PROBES=1" });
    nodes.push({ id: "lenovo", lastSeen: null, status: "unknown", detail: "enable FLEET_SSH_PROBES=1" });
  }

  const payload = normalizePayload(nodes);
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const outPath = path.join(OUT_DIR, "fleet-status.json");
  fs.writeFileSync(outPath, JSON.stringify(payload, null, 2));
  console.log(`wrote ${outPath}`);
  console.log(
    payload.nodes.map((n) => `${n.id}:${n.status}`).join(" · "),
  );

  if (!hasFlag("--publish")) return;
  const baseUrl = process.env.BOARD_PUBLISH_URL || process.env.SITE_ORIGIN || "https://www.sellersfirsthomesolutions.com";
  const secret = process.env.BOARD_PUBLISH_SECRET;
  if (!secret) {
    console.error("BOARD_PUBLISH_SECRET missing — wrote local file only");
    process.exit(2);
  }
  await publishKey(baseUrl, secret, "internal:fleet-status", payload);
  console.log("published internal:fleet-status");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
