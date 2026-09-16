#!/usr/bin/env node
/**
 * MSI Command Desk sync hub
 *
 * Scans ~/Projects/active/deal-packets → packet-status + geo-cache,
 * merges optional Gmail/Drive signal JSON → desk-sync,
 * optionally POSTs to /api/board-publish (BOARD_PUBLISH_SECRET).
 *
 * Usage:
 *   node scripts/desk-sync.mjs                 # write JSON under .cache/desk-sync/
 *   node scripts/desk-sync.mjs --publish       # also push to site if env set
 *   node scripts/desk-sync.mjs --signals path/to/signals.json
 *
 * Signals JSON shape:
 *   { "emails": [...], "driveFiles": [...], "sources": { ... } }
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildDeskSync,
  buildGeoCache,
  buildPacketStatus,
  loadJson,
} from "./lib/desk-sync-core.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const DEFAULT_PACKETS = path.resolve(ROOT, "../deal-packets");
const OUT_DIR = path.join(ROOT, ".cache", "desk-sync");

function argValue(flag) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return null;
  return process.argv[idx + 1] || null;
}

function hasFlag(flag) {
  return process.argv.includes(flag);
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
    const text = await res.text();
    throw new Error(`publish ${key} failed: ${res.status} ${text}`);
  }
  return res.json();
}

async function main() {
  const packetRoot = argValue("--packets") || process.env.DEAL_PACKETS_DIR || DEFAULT_PACKETS;
  const signalsPath = argValue("--signals") || path.join(ROOT, "scripts", "fixtures", "desk-signals.sample.json");
  const outDir = argValue("--out") || OUT_DIR;
  const doPublish = hasFlag("--publish");

  if (!fs.existsSync(packetRoot)) {
    console.error(`deal-packets not found: ${packetRoot}`);
    process.exit(1);
  }

  const packetStatus = buildPacketStatus(packetRoot);
  const geoCache = buildGeoCache(packetStatus);
  const signals = loadJson(signalsPath, { emails: [], driveFiles: [], sources: { sample: true } }) || {
    emails: [],
    driveFiles: [],
  };
  const deskSync = buildDeskSync(packetStatus, signals);

  fs.mkdirSync(outDir, { recursive: true });
  const write = (name, data) => {
    const file = path.join(outDir, name);
    fs.writeFileSync(file, JSON.stringify(data, null, 2));
    return file;
  };
  const files = {
    packetStatus: write("packet-status.json", packetStatus),
    geoCache: write("geo-cache.json", geoCache),
    deskSync: write("desk-sync.json", deskSync),
  };

  console.log(JSON.stringify({
    ok: true,
    packetRoot,
    signalsPath: fs.existsSync(signalsPath) ? signalsPath : null,
    counts: {
      packets: packetStatus.count,
      geo: geoCache.count,
      emails: deskSync.emailCount,
      drive: deskSync.driveCount,
    },
    files,
    published: false,
  }, null, 2));

  if (!doPublish) return;

  const secret = process.env.BOARD_PUBLISH_SECRET;
  const baseUrl = process.env.BOARD_PUBLISH_URL || process.env.SFHS_SITE_URL || "https://www.sellersfirsthomesolutions.com";
  if (!secret) {
    console.error("BOARD_PUBLISH_SECRET missing — wrote local cache only.");
    process.exit(2);
  }

  await publishKey(baseUrl, secret, "internal:packet-status", packetStatus);
  await publishKey(baseUrl, secret, "internal:geo-cache", geoCache);
  await publishKey(baseUrl, secret, "internal:desk-sync", deskSync);
  console.log(JSON.stringify({ published: true, baseUrl }, null, 2));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
