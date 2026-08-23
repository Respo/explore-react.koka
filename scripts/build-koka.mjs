import {
  copyFileSync,
  existsSync,
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
const stagedOutputDir = resolve(rootDir, ".koka-generated-next");
const wrapperPath = resolve(rootDir, "src/generated/koka-entry.mjs");
const wrapperTypesPath = resolve(rootDir, "src/generated/koka-entry.d.ts");
const sourcePath = "app.kk";

function copyFileIfChanged(sourcePath, targetPath) {
  if (
    !existsSync(targetPath) ||
    !readFileSync(sourcePath).equals(readFileSync(targetPath))
  ) {
    copyFileSync(sourcePath, targetPath);
  }
}

function writeFileIfChanged(filePath, content) {
  if (!existsSync(filePath) || readFileSync(filePath, "utf8") !== content) {
    writeFileSync(filePath, content, "utf8");
  }
}

rmSync(stagedOutputDir, { force: true, recursive: true });
mkdirSync(stagedOutputDir, { recursive: true });
rmSync(wrapperTypesPath, { force: true });

const result = spawnSync(
  "koka",
  [
    "--target=jsweb",
    "--library",
    "--builddir=.koka-build",
    `--outputdir=${stagedOutputDir}`,
    "--output=koka-app",
    sourcePath,
  ],
  {
    cwd: sourceDir,
    stdio: "inherit",
  },
);

if (result.status !== 0) {
  rmSync(stagedOutputDir, { force: true, recursive: true });
  process.exit(result.status ?? 1);
}

const stagedFiles = readdirSync(stagedOutputDir);
const entryFile = stagedFiles
  .filter((fileName) => fileName.endsWith(".mjs"))
  .find((fileName) =>
    readFileSync(resolve(stagedOutputDir, fileName), "utf8").includes(
      "export function boot(",
    ),
  );

if (entryFile == null) {
  rmSync(stagedOutputDir, { force: true, recursive: true });
  throw new Error(
    "Could not find the generated Koka entry module exporting boot().",
  );
}

// Keep the watched output directory valid throughout a rebuild. Deleting it
// first makes Vite observe a burst of missing modules before Koka finishes.
mkdirSync(outputDir, { recursive: true });
for (const fileName of stagedFiles) {
  copyFileIfChanged(
    resolve(stagedOutputDir, fileName),
    resolve(outputDir, fileName),
  );
}
for (const fileName of readdirSync(outputDir)) {
  if (!stagedFiles.includes(fileName)) {
    rmSync(resolve(outputDir, fileName), { force: true, recursive: true });
  }
}
rmSync(stagedOutputDir, { force: true, recursive: true });

mkdirSync(dirname(wrapperPath), { recursive: true });
writeFileIfChanged(
  wrapperPath,
  [
    `export { boot, boot__with__snapshot as bootWithSnapshot, dispatch__click__bridge as dispatchClick, dispatch__input__bridge as dispatchInput, dispatch__route__bridge as dispatchRoute, export__state__snapshot__bridge as exportStateSnapshot } from './koka/${entryFile}';`,
    "",
  ].join("\n"),
);
