import "./style.css";
import * as initialRuntime from "./generated/koka-entry";

const root = document.querySelector("#app");
const stateSnapshotKey = "koka-respo:component-state:v1";
let runtime = initialRuntime;

if (root === null) {
  throw new Error("Missing #app root element.");
}

function saveSnapshot() {
  const snapshot = runtime.exportStateSnapshot();
  try {
    localStorage.setItem(stateSnapshotKey, snapshot);
  } catch (error) {
    console.warn("Could not persist the Respo component-state snapshot.", error);
  }
  return snapshot;
}

function loadSnapshot() {
  try {
    return localStorage.getItem(stateSnapshotKey) ?? "";
  } catch (error) {
    console.warn("Could not restore the Respo component-state snapshot.", error);
    return "";
  }
}

function installBridges() {
  window.__kokaDispatchClick = (payload) => {
    runtime.dispatchClick(payload);
    saveSnapshot();
  };
  window.__kokaDispatchInput = (channel, value) => {
    runtime.dispatchInput(channel, value);
    saveSnapshot();
  };
  window.__kokaDispatchRoute = (routeName) => {
    runtime.dispatchRoute(routeName);
    saveSnapshot();
  };
}

const restoredSnapshot =
  import.meta.hot?.data.stateSnapshot ?? loadSnapshot();

installBridges();
runtime.bootWithSnapshot("app", restoredSnapshot);

if (import.meta.hot) {
  import.meta.hot.accept("./generated/koka-entry", (nextRuntime) => {
    if (nextRuntime == null) {
      return;
    }
    const snapshot = runtime.exportStateSnapshot();
    runtime = nextRuntime;
    installBridges();
    runtime.bootWithSnapshot("app", snapshot);
    saveSnapshot();
  });

  import.meta.hot.dispose((data) => {
    data.stateSnapshot = saveSnapshot();
  });
}
