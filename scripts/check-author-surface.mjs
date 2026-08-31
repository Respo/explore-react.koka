import { readFileSync, readdirSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = resolve(fileURLToPath(new URL("..", import.meta.url)));
const authorEntryPath = resolve(rootDir, "explore/react.kk");
const allowedExports = [
  "pub import explore/react/core",
  "pub import explore/react/action",
  "pub import explore/react/state",
];
const forbiddenAuthorImports = [
  "import explore/react/core",
  "import explore/react/action",
  "import explore/react/state",
];

function kokaFiles(directory) {
  return readdirSync(directory).flatMap((name) => {
    const path = resolve(directory, name);
    if (statSync(path).isDirectory()) {
      return kokaFiles(path);
    }
    return name.endsWith(".kk") ? [path] : [];
  });
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
].filter(
  (path) =>
    !path.includes("/demo/tests/") &&
    !path.endsWith("/demo/tests.kk") &&
    !path.endsWith("/demo/runtimeframe.kk"),
);

const violations = businessFiles.filter((path) => {
  const source = readFileSync(path, "utf8");
  return forbiddenAuthorImports.some((line) => source.includes(line));
});

if (violations.length > 0) {
  throw new Error(
    `Business modules must use import explore/react:\n${violations.join("\n")}`,
  );
}

console.log(
  `Author surface OK: one entry, three re-exports, ${businessFiles.length} business modules checked.`,
);
