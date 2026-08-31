import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = resolve(fileURLToPath(new URL("..", import.meta.url)));
const result = spawnSync(
  "koka",
  [
    "--target=jsnode",
    "--builddir=.koka-example",
    "--execute",
    "examples/first_component/main.kk",
  ],
  { cwd: rootDir, encoding: "utf8" },
);

process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

const expectedOutput = [
  "Initial UI:",
  "State: closed",
  "Typed action: Toggle_disclosure example/disclosure-action@1 payload=toggle",
  "Updated UI:",
  "State: open",
];

const missing = expectedOutput.filter((text) => !result.stdout.includes(text));
if (missing.length > 0) {
  console.error(`First-component output is missing: ${missing.join(", ")}`);
  process.exit(1);
}
