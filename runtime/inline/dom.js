function _root_of(rootId) {
  const root = document.getElementById(rootId);

  if (root == null) {
    throw new Error(`Missing root element: ${rootId}`);
  }

  return root;
}

function _mount_html(rootId, html) {
  _root_of(rootId).innerHTML = html;
}

function _attach_events(rootId) {
  const root = _root_of(rootId);

  if (root.dataset.kokaAttached === "true") {
    return;
  }

  root.dataset.kokaAttached = "true";

  root.addEventListener("click", (event) => {
    const target = event.target;

    if (!(target instanceof Element)) {
      return;
    }

    const clickable = target.closest("[data-k-click]");

    if (clickable instanceof HTMLElement) {
      const payload = String(clickable.dataset.kClick ?? "");

      if (clickable.dataset.kDialogDismiss === "true") {
        event.preventDefault();
        _dispatch_dialog_dismiss(rootId, payload);
        return;
      }

      globalThis.__kokaDispatchClick?.(payload);
    }
  });

  root.addEventListener("input", (event) => {
    const target = event.target;

    if (
      !(target instanceof HTMLInputElement) &&
      !(target instanceof HTMLTextAreaElement)
    ) {
      return;
    }

    const channel = target.dataset.kInput;

    if (typeof channel === "string") {
      globalThis.__kokaDispatchInput?.(channel, target.value);
    }
  });

  root.addEventListener("keydown", (event) => {
    const target = event.target;

    if (
      !(target instanceof HTMLInputElement) &&
      !(target instanceof HTMLTextAreaElement)
    ) {
      return;
    }

    if (event.key !== "Enter") {
      return;
    }

    const payload = target.dataset.kEnter;

    if (typeof payload === "string") {
      event.preventDefault();
      globalThis.__kokaDispatchClick?.(payload);
    }
  });

  window.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") {
      return;
    }

    const dialogShell = _active_dialog_shell(root);

    if (!(dialogShell instanceof HTMLElement)) {
      return;
    }

    const payload = dialogShell.dataset.kDialogClose;

    if (typeof payload !== "string" || payload === "") {
      return;
    }

    event.preventDefault();
    _dispatch_dialog_dismiss(rootId, payload);
  });

  window.addEventListener("hashchange", () => {
    globalThis.__kokaDispatchRoute?.(_browser_hash());
  });
}

function _active_dialog_shell(root) {
  const shell = root.querySelector("[data-k-dialog-shell='true']");
  return shell instanceof HTMLElement ? shell : null;
}

function _clone_dialog_for_exit(shell) {
  const cloned = shell.cloneNode(true);

  if (!(cloned instanceof HTMLElement)) {
    return;
  }

  cloned.classList.add("dialog-exit-ghost");
  cloned
    .querySelectorAll(
      "[data-k-click],[data-k-input],[data-k-enter],[data-k-dialog-dismiss]",
    )
    .forEach((node) => {
      if (node instanceof Element) {
        node.removeAttribute("data-k-click");
        node.removeAttribute("data-k-input");
        node.removeAttribute("data-k-enter");
        node.removeAttribute("data-k-dialog-dismiss");
      }
    });

  document.body.appendChild(cloned);

  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => {
      cloned.classList.add("dialog-exit-ghost-leaving");
    });
  });

  window.setTimeout(() => {
    cloned.remove();
  }, 280);
}

function _dispatch_dialog_dismiss(rootId, payload) {
  const root = _root_of(rootId);
  const shell = _active_dialog_shell(root);

  if (shell instanceof HTMLElement) {
    _clone_dialog_for_exit(shell);
  }

  globalThis.__kokaDispatchClick?.(payload);
}

function _patch_html(rootId, path, html) {
  const root = _root_of(rootId);

  if (path === "0") {
    root.innerHTML = html;
    return;
  }

  const current = root.querySelector(`[data-kpath="${path}"]`);

  if (current == null) {
    return;
  }

  const template = document.createElement("template");
  template.innerHTML = html.trim();
  const next = template.content.firstElementChild;

  if (next != null) {
    current.replaceWith(next);
  }
}

function _node_at(rootId, path) {
  const root = _root_of(rootId);

  if (path === "0") {
    return root.querySelector('[data-kpath="0"]') ?? root.firstElementChild;
  }

  return root.querySelector(`[data-kpath="${path}"]`);
}

function _patch_attr(rootId, path, attrName, attrValue) {
  const current = _node_at(rootId, path);

  if (!(current instanceof Element)) {
    return;
  }

  current.setAttribute(attrName, attrValue);

  if (
    attrName === "value" &&
    (current instanceof HTMLInputElement ||
      current instanceof HTMLTextAreaElement)
  ) {
    if (current.value !== attrValue) {
      current.value = attrValue;
    }
  }
}

function _clear_attr(rootId, path, attrName) {
  const current = _node_at(rootId, path);

  if (!(current instanceof Element)) {
    return;
  }

  current.removeAttribute(attrName);

  if (
    attrName === "value" &&
    (current instanceof HTMLInputElement ||
      current instanceof HTMLTextAreaElement)
  ) {
    if (current.value !== "") {
      current.value = "";
    }
  }
}

function _sync_input(rootId, fieldName, value) {
  const root = _root_of(rootId);
  const field = root.querySelector(`[data-k-input="${fieldName}"]`);

  if (
    field instanceof HTMLInputElement ||
    field instanceof HTMLTextAreaElement
  ) {
    if (field.value !== value) {
      field.value = value;
    }
  }
}

function _browser_hash() {
  return String(window.location.hash || "").replace(/^#/, "");
}

function _browser_set_hash(routeName) {
  const nextHash = `#${String(routeName || "overview")}`;

  if (window.location.hash !== nextHash) {
    window.location.hash = nextHash;
  }
}

function _browser_focus(rootId, fieldName) {
  const root = _root_of(rootId);
  const field =
    root.querySelector(`[data-k-effect="${fieldName}"]`) ||
    root.querySelector(`[data-k-input="${fieldName}"]`);

  if (field instanceof HTMLElement && typeof field.focus === "function") {
    try {
      field.focus({ preventScroll: true });
    } catch (_error) {
      field.focus();
    }
  }
}

function _browser_flash_marker(rootId, markerName, className) {
  const root = _root_of(rootId);
  const target = root.querySelector(`[data-k-effect="${markerName}"]`);

  if (!(target instanceof HTMLElement)) {
    return;
  }

  target.classList.remove(className);
  void target.offsetWidth;
  target.classList.add(className);

  window.setTimeout(() => {
    target.classList.remove(className);
  }, 360);
}

function _browser_now_label() {
  return new Date().toLocaleTimeString("en-US", {
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function _browser_confirm(message) {
  return window.confirm(message);
}

function _browser_log(message) {
  console.log(message);
}

function _browser_schedule_click(payload, delay) {
  window.setTimeout(
    () => {
      globalThis.__kokaDispatchClick?.(String(payload));
    },
    Number(delay) || 0,
  );
}

function _html_escape(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

let _current_root_id = "app";

function _set_root_id(id) {
  _current_root_id = String(id);
}

function _dom_focus(fieldName) {
  _browser_focus(_current_root_id, fieldName);
}

function _dom_flash(markerName, className) {
  _browser_flash_marker(_current_root_id, markerName, className);
}
