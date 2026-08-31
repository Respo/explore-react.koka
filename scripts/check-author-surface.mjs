import { readFileSync, readdirSync, statSync } from "node:fs";
import { relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = resolve(fileURLToPath(new URL("..", import.meta.url)));
const authorEntryPath = resolve(rootDir, "explore/react.kk");
const allowedExports = [
  "pub import explore/react/core",
  "pub import explore/react/action",
  "pub import explore/react/state",
];
const forbiddenBusinessImport =
  /^\s*(?:pub\s+)?import\s+(?:(?:[A-Za-z_][A-Za-z0-9_]*)\s*=\s*)?explore\/react\/(?:core|action|state|runtime|inspection|renderer)\s*(?:\/\/.*)?$/m;

/** Collect Koka source files recursively from a known project directory. */
function kokaFiles(directory) {
  return readdirSync(directory).flatMap((name) => {
    const path = resolve(directory, name);
    if (statSync(path).isDirectory()) {
      return kokaFiles(path);
    }
    return name.endsWith(".kk") ? [path] : [];
  });
}

/** Keep host-owned test and runtime modules out of the component-author check. */
function isAdvancedDemoModule(path) {
  const [topLevel, module] = relative(rootDir, path).split(sep);
  return (
    topLevel === "demo" &&
    (module === "tests" || module === "tests.kk" || module === "runtimeframe.kk")
  );
}

const authorEntry = readFileSync(authorEntryPath, "utf8");
const exportedImports = authorEntry
  .split("\n")
  .map((line) => line.trim())
  .filter((line) => line.startsWith("pub import "));

if (
  exportedImports.length !== allowedExports.length ||
  allowedExports.some((line) => !exportedImports.includes(line))
) {
  throw new Error(
    "explore/react.kk must re-export exactly core, action, and state.",
  );
}

const businessFiles = [
  ...kokaFiles(resolve(rootDir, "library")),
  ...kokaFiles(resolve(rootDir, "demo")),
  ...kokaFiles(resolve(rootDir, "examples")).filter((path) =>
    relative(rootDir, path).split(sep).at(-1) === "component.kk"),
].filter((path) => !isAdvancedDemoModule(path));

const violations = businessFiles.filter((path) => {
  const source = readFileSync(path, "utf8");
  return forbiddenBusinessImport.test(source);
});

if (violations.length > 0) {
  throw new Error(
    `Business modules must use import explore/react instead of a direct framework module:\n${violations.join("\n")}`,
  );
}

console.log(
  `Author surface OK: one entry, three re-exports, ${businessFiles.length} business modules checked.`,
);
