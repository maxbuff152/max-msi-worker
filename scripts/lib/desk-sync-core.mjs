#!/usr/bin/env node
/**
 * Desk-sync core — scan deal-packets + optional Gmail/Drive signal JSON,
 * produce packet-status, geo-cache, and desk-sync payloads for board-publish.
 *
 * Pure helpers (no network). CLI lives in desk-sync.mjs.
 */

import fs from "node:fs";
import path from "node:path";

const SKIP_DIRS = new Set([
  "node_modules", ".git", "__pycache__", "tmp", "scratch", "_templates", "logan-comps",
]);

export function normalizeAddressKey(address) {
  return String(address || "")
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function parseMoney(text) {
  if (text == null) return null;
  const cleaned = String(text).replace(/[,$]/g, "").replace(/\s/g, "");
  if (/comp\s*pending/i.test(cleaned)) return null;
  const n = Number(cleaned.replace(/[^0-9.]/g, ""));
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** Pull Subject + Suggested ARV + source + median DOM from ARV-REPORT.md */
export function parseArvReport(markdown, slug) {
  const text = String(markdown || "");
  const subjectMatch = text.match(/\*\*Subject:\*\*\s*(.+)/i) || text.match(/^#\s*ARV Report[^\n]*\n[\s\S]*?\*\*Subject:\*\*\s*(.+)/i);
  const address = subjectMatch ? subjectMatch[1].trim() : "";
  const arvRow = text.match(/Suggested ARV\s*\|\s*\*?\*?\s*([^|\n]+)/i);
  const arvCell = arvRow ? arvRow[1].replace(/\*/g, "").trim() : "";
  const pending = /comp\s*pending/i.test(arvCell) || /comp\s*pending/i.test(text.slice(0, 800));
  const arv = pending ? null : parseMoney(arvCell);
  let arvSource = null;
  const srcParen = arvCell.match(/\(([^)]+)\)/);
  if (srcParen) arvSource = srcParen[1].trim();
  else if (pending) arvSource = "comp-pending";
  else if (/logan-primary/i.test(text)) arvSource = "logan-primary";
  else if (/neighborhood-median/i.test(text)) arvSource = "neighborhood-median";
  else if (/public pre/i.test(text)) arvSource = "public-preuw";

  const domMatch = text.match(/\*\*Median DOM\*\*\s*\|\s*\*\*?\s*([0-9.]+)/i)
    || text.match(/Median DOM\s*\|\s*\*?\*?\s*([0-9.]+)/i);
  const medianDom = domMatch ? Number(domMatch[1]) : null;

  return {
    slug,
    address,
    addressKey: normalizeAddressKey(address),
    arv,
    arvSource,
    medianDom: Number.isFinite(medianDom) ? medianDom : null,
    hasAdvance: false,
    buyReady: false,
    pending,
  };
}

function fsExistsSafe(p) {
  try { return fs.existsSync(p); } catch { return false; }
}

export function scanPacketDir(packetRoot, slug) {
  const dir = path.join(packetRoot, slug);
  const arvPath = path.join(dir, "ARV-REPORT.md");
  if (!fsExistsSafe(arvPath)) return null;
  const markdown = fs.readFileSync(arvPath, "utf8");
  const entry = parseArvReport(markdown, slug);
  entry.hasAdvance = fsExistsSafe(path.join(dir, "ADVANCE.md"))
    || fsExistsSafe(path.join(dir, "Hatch-Advance-Report-2026-09-11.pdf"))
    || /advance/i.test(slug);
  entry.packetPath = slug;
  entry.updatedAt = fs.statSync(arvPath).mtime.toISOString();
  if (entry.pending) {
    entry.compStatus = "comp-pending";
  } else if (entry.hasAdvance && /logan/i.test(entry.arvSource || "")) {
    entry.compStatus = "advance-ready";
  } else if (/logan/i.test(entry.arvSource || "")) {
    entry.compStatus = "logan-primary";
  } else if (entry.arv != null) {
    entry.compStatus = "public-preuw";
  } else {
    entry.compStatus = "comp-pending";
  }
  return entry;
}

export function listPacketSlugs(packetRoot) {
  if (!fsExistsSafe(packetRoot)) return [];
  return fs.readdirSync(packetRoot, { withFileTypes: true })
    .filter((d) => d.isDirectory() && !SKIP_DIRS.has(d.name) && !d.name.startsWith("."))
    .map((d) => d.name)
    .filter((slug) => fsExistsSafe(path.join(packetRoot, slug, "ARV-REPORT.md")))
    .sort();
}

export function buildPacketStatus(packetRoot) {
  const bySlug = {};
  for (const slug of listPacketSlugs(packetRoot)) {
    const entry = scanPacketDir(packetRoot, slug);
    if (entry) bySlug[slug] = entry;
  }
  return {
    generatedAt: new Date().toISOString(),
    bySlug,
    count: Object.keys(bySlug).length,
  };
}

/** Known Houston deal pins — avoid live geocode in CI; MSI can merge overrides. */
export const KNOWN_GEO = Object.freeze({
  "16915 hatch ct crosby tx 77532": { lat: 29.9112, lng: -95.0621, precision: "street", provider: "manual" },
  "14722 sun harbor dr houston tx 77062": { lat: 29.5688, lng: -95.1235, precision: "street", provider: "manual" },
  "5754 cheltenham dr houston tx 77096": { lat: 29.6765, lng: -95.4792, precision: "street", provider: "manual" },
  "6817 kassarine pass houston tx 77033": { lat: 29.6578, lng: -95.3371, precision: "street", provider: "manual" },
  "2110 flynn dr pasadena tx 77502": { lat: 29.6904, lng: -95.1898, precision: "street", provider: "manual" },
  "4116 castor st houston tx 77022": { lat: 29.8321, lng: -95.3854, precision: "street", provider: "manual" },
  "7118 bahia ln missouri city tx 77489": { lat: 29.5632, lng: -95.5378, precision: "street", provider: "manual" },
});

export function buildGeoCache(packetStatus, overrides = {}) {
  const byAddress = {};
  const merge = { ...KNOWN_GEO, ...overrides };
  for (const entry of Object.values(packetStatus.bySlug || {})) {
    const key = entry.addressKey || normalizeAddressKey(entry.address);
    if (!key) continue;
    const hit = merge[key] || Object.entries(merge).find(([k]) => key.includes(k) || k.includes(key))?.[1];
    if (!hit) continue;
    byAddress[key] = {
      address: entry.address,
      addressKey: key,
      lat: hit.lat,
      lng: hit.lng,
      precision: hit.precision || "approx",
      provider: hit.provider || "manual",
      at: new Date().toISOString(),
    };
  }
  return {
    generatedAt: new Date().toISOString(),
    byAddress,
    count: Object.keys(byAddress).length,
  };
}

function matchDealSlug(haystack, packets) {
  const text = normalizeAddressKey(haystack);
  if (!text) return null;
  const STREET_SUFFIX = new Set(["ct", "dr", "st", "ln", "ave", "rd", "blvd", "way", "pl", "cir", "pass", "tr", "trl"]);
  let best = null;
  let bestScore = 0;
  for (const packet of packets) {
    const slug = String(packet.slug || "").toLowerCase();
    const addressKey = packet.addressKey || normalizeAddressKey(packet.address);
    const tokens = (addressKey || "").split(" ").filter(Boolean);
    const streetCore = tokens
      .filter((t, i) => !(i === 0 && /^\d+$/.test(t)) && !STREET_SUFFIX.has(t) && !/^(tx|texas|houston|crosby|pasadena)$/.test(t) && !/^\d{5}$/.test(t))
      .slice(0, 3)
      .join(" ");
    const streetWithNum = tokens.slice(0, 3).join(" ");
    const slugBits = slug.replace(/-advance$/, "").replace(/-/g, " ");
    const slugName = slugBits.replace(/\s+\d+$/, "").trim();
    let score = 0;
    if (streetWithNum && text.includes(streetWithNum)) score += 5;
    if (streetCore && streetCore.length >= 4 && text.includes(streetCore)) score += 4;
    if (slugBits && text.includes(slugBits)) score += 4;
    if (slugName && slugName.length >= 4 && text.includes(slugName)) score += 3;
    const num = (addressKey || "").match(/^(\d+)\s+(\w+)/);
    if (num && text.includes(`${num[1]} ${num[2]}`)) score += 4;
    if (score > bestScore) {
      bestScore = score;
      best = packet.slug;
    }
  }
  return bestScore >= 3 ? best : null;
}

function isNoiseEmail(subject, snippet) {
  return /system test|synthetic|do not contact|e2e|reliability lane|999 test/i.test(`${subject} ${snippet}`);
}

export function buildDeskSync(packetStatus, signals = {}) {
  const packets = Object.values(packetStatus.bySlug || {});
  const emails = [];
  for (const raw of Array.isArray(signals.emails) ? signals.emails : []) {
    const subject = String(raw.subject || "").trim() || "(no subject)";
    const snippet = String(raw.snippet || "").trim();
    if (isNoiseEmail(subject, snippet)) continue;
    const dealSlug = raw.dealSlug || matchDealSlug(`${subject} ${snippet} ${raw.address || ""}`, packets);
    emails.push({
      id: raw.id || raw.threadId || `${subject}|${raw.date || raw.when || ""}`,
      subject,
      from: raw.from || raw.sender || "",
      when: raw.when || raw.date || null,
      snippet: snippet.slice(0, 220),
      url: raw.url || (raw.threadId ? `https://mail.google.com/mail/u/0/#inbox/${raw.threadId}` : null),
      dealSlug: dealSlug || null,
    });
  }
  const driveFiles = [];
  for (const raw of Array.isArray(signals.driveFiles || signals.files) ? (signals.driveFiles || signals.files) : []) {
    const name = String(raw.name || raw.title || "Drive file").trim();
    const dealSlug = raw.dealSlug || matchDealSlug(`${name} ${raw.address || ""}`, packets);
    driveFiles.push({
      id: raw.id || `${name}|${raw.modifiedTime || raw.when || ""}`,
      name,
      kind: raw.kind || raw.mimeType || "Drive",
      when: raw.when || raw.modifiedTime || null,
      url: raw.url || raw.viewUrl || raw.webViewLink || null,
      dealSlug: dealSlug || null,
    });
  }
  return {
    generatedAt: new Date().toISOString(),
    emails,
    driveFiles,
    emailCount: emails.length,
    driveCount: driveFiles.length,
    packetCount: packetStatus.count || packets.length,
    sources: signals.sources || { packets: true, emails: Boolean(emails.length), drive: Boolean(driveFiles.length) },
  };
}

export function loadJson(filePath, fallback = null) {
  if (!filePath || !fsExistsSafe(filePath)) return fallback;
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}
