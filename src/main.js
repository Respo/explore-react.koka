import "./style.css";
import {
  boot,
  dispatchClick,
  dispatchInput,
  dispatchRoute,
} from "./generated/koka-entry";

const root = document.querySelector("#app");

if (root === null) {
  throw new Error("Missing #app root element.");
}

window.__kokaDispatchClick = dispatchClick;
window.__kokaDispatchInput = dispatchInput;
window.__kokaDispatchRoute = dispatchRoute;

boot("app");
