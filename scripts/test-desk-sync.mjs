#!/usr/bin/env node
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildDeskSync,
  buildGeoCache,
  buildPacketStatus,
  parseArvReport,
  parseMoney,
} from "./lib/desk-sync-core.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function test(name, fn) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (error) {
    console.error(`not ok - ${name}`);
    throw error;
  }
}

test("parseMoney ignores Comp pending", () => {
  assert.equal(parseMoney("**Comp pending**"), null);
  assert.equal(parseMoney("$251,391 (logan-primary)"), 251391);
});

test("parseArvReport extracts Hatch logan-primary", () => {
  const md = `# ARV Report — Hatch
**Subject:** 16915 Hatch Ct, Crosby, TX 77532
| Suggested ARV | $251,391 (logan-primary) |
| **Median DOM** | **35** |
`;
  const entry = parseArvReport(md, "hatch-advance");
  assert.equal(entry.arv, 251391);
  assert.equal(entry.arvSource, "logan-primary");
  assert.equal(entry.medianDom, 35);
  assert.equal(entry.pending, false);
});

test("buildPacketStatus scans real deal-packets when present", () => {
  const root = path.resolve(__dirname, "../../deal-packets");
  if (!fs.existsSync(path.join(root, "hatch-advance", "ARV-REPORT.md"))) {
    console.log("skip - deal-packets hatch not on disk");
    return;
  }
  const status = buildPacketStatus(root);
  assert.ok(status.count >= 3);
  assert.ok(status.bySlug["hatch-advance"]);
  assert.equal(status.bySlug["hatch-advance"].compStatus, "advance-ready");
  assert.ok(status.bySlug["sun-harbor-14722"]);
  assert.equal(status.bySlug["sun-harbor-14722"].compStatus, "comp-pending");
});

test("buildGeoCache pins known Houston addresses", () => {
  const status = {
    count: 1,
    bySlug: {
      "hatch-advance": {
        slug: "hatch-advance",
        address: "16915 Hatch Ct, Crosby, TX 77532",
        addressKey: "16915 hatch ct crosby tx 77532",
      },
    },
  };
  const geo = buildGeoCache(status);
  assert.equal(geo.count, 1);
  assert.ok(geo.byAddress["16915 hatch ct crosby tx 77532"].lat);
});

test("buildDeskSync matches synthetic signals and drops noise", () => {
  const sample = JSON.parse(
    fs.readFileSync(path.join(__dirname, "fixtures", "desk-signals.sample.json"), "utf8"),
  );
  assert.equal(sample.sources.synthetic, true);
  for (const email of sample.emails) {
    assert.match(email.id, /^fixture-email-/);
    assert.match(email.from, /@example\.invalid$/);
    if (email.threadId) assert.match(email.threadId, /^fixture-thread-/);
    if (email.url) assert.equal(new URL(email.url).hostname, "example.invalid");
  }
  for (const file of sample.driveFiles) {
    assert.match(file.id, /^fixture-drive-/);
    assert.equal(new URL(file.viewUrl).hostname, "example.invalid");
    assert.match(file.title, /Example/);
  }
  const status = {
    count: 3,
    bySlug: {
      "example-cedar-101": {
        slug: "example-cedar-101",
        address: "101 Example Cedar Dr",
        addressKey: "101 example cedar dr",
      },
      "example-birch-202": {
        slug: "example-birch-202",
        address: "202 Example Birch Ct",
        addressKey: "202 example birch ct",
      },
      "example-maple-303": {
        slug: "example-maple-303",
        address: "303 Example Maple Ln",
        addressKey: "303 example maple ln",
      },
    },
  };
  const sync = buildDeskSync(status, sample);
  assert.equal(sync.emailCount, 2);
  assert.equal(sync.driveCount, 7);
  assert.deepEqual(sync.emails.map((e) => e.dealSlug),
    ["example-cedar-101", "example-birch-202"]);
  assert.ok(!sync.emails.some((e) => /SYSTEM TEST/i.test(e.subject)));
  assert.deepEqual(sync.driveFiles.map((f) => f.dealSlug),
    ["example-cedar-101", "example-birch-202", "example-maple-303",
      "example-maple-303", "example-maple-303", null, null]);
  for (const record of [...sync.emails, ...sync.driveFiles]) {
    assert.equal(new URL(record.url).hostname, "example.invalid");
  }
});

test("tmp packet dir still builds empty-safe status", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "desk-sync-"));
  const status = buildPacketStatus(dir);
  assert.equal(status.count, 0);
  fs.rmSync(dir, { recursive: true, force: true });
});

console.log("\nAll MSI desk-sync tests passed.");
