import "./style.css";
import * as initialRuntime from "./generated/koka-entry";

const root = document.querySelector("#app");
const stateSnapshotKey = "koka-respo:component-state:v1";
let runtime = initialRuntime;
let snapshotWriteFrame = null;

if (root === null) {
  throw new Error("Missing #app root element.");
}

function writeSnapshot(snapshot) {
  try {
    localStorage.setItem(stateSnapshotKey, snapshot);
  } catch (error) {
    console.warn("Could not persist the Respo component-state snapshot.", error);
  }
  return snapshot;
}

function flushSnapshot() {
  if (snapshotWriteFrame !== null) {
    cancelAnimationFrame(snapshotWriteFrame);
    snapshotWriteFrame = null;
  }
  const snapshot = runtime.exportStateSnapshot();
  return writeSnapshot(snapshot);
}

function scheduleSnapshotSave() {
  if (snapshotWriteFrame !== null) {
    return;
  }
  snapshotWriteFrame = requestAnimationFrame(() => {
    snapshotWriteFrame = null;
    writeSnapshot(runtime.exportStateSnapshot());
  });
}

function loadSnapshot() {
  try {
    return localStorage.getItem(stateSnapshotKey) ?? "";
  } catch (error) {
    console.warn("Could not restore the Respo component-state snapshot.", error);
    return "";
  }
}

function disposeRuntime() {
  runtime.disposeRuntime();
}

function installBridges() {
  window.__kokaDispatchClick = (payload) => {
    runtime.dispatchClick(payload);
    scheduleSnapshotSave();
  };
  window.__kokaDispatchInput = (channel, value) => {
    runtime.dispatchInput(channel, value);
    scheduleSnapshotSave();
  };
  window.__kokaDispatchRoute = (routeName) => {
    runtime.dispatchRoute(routeName);
    scheduleSnapshotSave();
  };
}

const restoredSnapshot =
  import.meta.hot?.data.stateSnapshot ?? loadSnapshot();

installBridges();
runtime.bootWithSnapshot("app", restoredSnapshot);
window.addEventListener("pagehide", flushSnapshot);

if (import.meta.hot) {
  import.meta.hot.accept("./generated/koka-entry", (nextRuntime) => {
    if (nextRuntime == null) {
      return;
    }
    const snapshot = flushSnapshot();
    disposeRuntime();
    runtime = nextRuntime;
    installBridges();
    runtime.bootWithSnapshot("app", snapshot);
    flushSnapshot();
  });

  import.meta.hot.dispose((data) => {
    data.stateSnapshot = flushSnapshot();
    disposeRuntime();
  });
}
