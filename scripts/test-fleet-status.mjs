import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(__dirname, "fleet-status.mjs");

function test(name, fn) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (error) {
    console.error(`not ok - ${name}`);
    throw error;
  }
}

test("fleet-status.mjs writes a three-node payload", () => {
  const res = spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: { ...process.env, FLEET_SSH_PROBES: "0" },
  });
  assert.equal(res.status, 0, res.stderr || res.stdout);
  assert.match(res.stdout, /msi:/);
  assert.match(res.stdout, /mac:/);
  assert.match(res.stdout, /lenovo:/);
});

console.log("\nAll MSI fleet-status tests passed.");
