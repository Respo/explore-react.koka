import {
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, resolve } from "node:path";

const rootDir = resolve(new URL("..", import.meta.url).pathname);
const sourceDir = rootDir;
const outputDir = resolve(rootDir, "src/generated/koka");
const wrapperPath = resolve(rootDir, "src/generated/koka-entry.mjs");
const wrapperTypesPath = resolve(rootDir, "src/generated/koka-entry.d.ts");
const sourcePath = "app.kk";

rmSync(outputDir, { force: true, recursive: true });
mkdirSync(outputDir, { recursive: true });
rmSync(wrapperTypesPath, { force: true });

const result = spawnSync(
  "koka",
  [
    "--target=jsweb",
    "--library",
    "--builddir=.koka-build",
    `--outputdir=${outputDir}`,
    "--output=koka-app",
    sourcePath,
  ],
  {
    cwd: sourceDir,
    stdio: "inherit",
  },
);

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

const entryFile = readdirSync(outputDir)
  .filter((fileName) => fileName.endsWith(".mjs"))
  .find((fileName) =>
    readFileSync(resolve(outputDir, fileName), "utf8").includes(
      "export function boot(",
    ),
  );

if (entryFile == null) {
  throw new Error(
    "Could not find the generated Koka entry module exporting boot().",
  );
}

mkdirSync(dirname(wrapperPath), { recursive: true });
writeFileSync(
  wrapperPath,
  [
    `export { boot, dispatch__click__bridge as dispatchClick, dispatch__input__bridge as dispatchInput, dispatch__route__bridge as dispatchRoute } from './koka/${entryFile}';`,
    "",
  ].join("\n"),
  "utf8",
);
