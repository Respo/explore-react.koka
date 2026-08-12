import { spawnSync } from "node:child_process";
import { resolve } from "node:path";

const rootDir = resolve(new URL("..", import.meta.url).pathname);
const sourceDir = rootDir;
const sourcePath = "tests_main.kk";

const result = spawnSync(
  "koka",
  ["--target=jsnode", "--builddir=.koka-test", "--execute", sourcePath],
  {
    cwd: sourceDir,
    stdio: "inherit",
  },
);

process.exit(result.status ?? 1);
