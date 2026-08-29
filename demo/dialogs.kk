module demo/dialogs

import library/dialog
import demo/model
import runtime/dom
import explore/react/core
import explore/react/state

fun apply_dialog_update(owner : model, next_update : dialog_update) : <div> model
  owner(dialog = next_update.dialog, notice = next_update.notice)

fun open_dialog_demo(owner : model, kind : dialog_kind, title : string, message : string, prompt_value : string = "", notice : string) : <div> model
  apply_dialog_update(owner, open_dialog(owner.dialog, kind = kind, title = title, message = message, prompt_value = prompt_value, notice = notice))

fun apply_audited_update(owner : model, next_update : dialog_update) : <browser_host,div> model
  match next_update.audit_message
    Just(message) -> {
      audit(message)
      apply_dialog_update(owner, next_update)
    }
    Nothing -> apply_dialog_update(owner, next_update)

fun prompt_submit(owner : model) : <browser_host,div> model
  apply_audited_update(owner, submit_dialog_prompt(owner.dialog, "Prompt dialog submitted through the overlay demo."))

fun dialog_primary_action(owner : model) : <browser_host,div> model
  val current = owner.dialog
  match current.kind
    Dialog_alert -> apply_audited_update(owner, resolve_dialog_primary(current, result_note = "Alert acknowledged.", notice = "Alert overlay acknowledged.", log_line = "[ack] alert overlay", audit_message = "Alert acknowledged."))
    Dialog_dialog -> apply_audited_update(owner, resolve_dialog_primary(current, result_note = "Dialog action completed.", notice = "Dialog overlay primary action completed.", log_line = "[accept] dialog overlay", audit_message = "Dialog action completed."))
    Dialog_drawer -> apply_audited_update(owner, resolve_dialog_primary(current, result_note = "Drawer action completed.", notice = "Drawer overlay primary action completed.", log_line = "[accept] drawer overlay", audit_message = "Drawer action completed."))
    _ -> owner

pub fun handle_dialog_click(payload : string, owner : model) : <browser_host,div> maybe<model>
  if payload == dialog_open_payload("alert") then
    Just(open_dialog_demo(owner, kind = Dialog_alert, title = "Alert demo", message = "A controlled alert surface rendered inside the app tree, similar to the explore-react demos in the MoonBit and Rust implementations.", notice = "Opened alert overlay demo."))
  else if payload == dialog_open_payload("prompt") then
    Just(open_dialog_demo(owner, kind = Dialog_prompt, title = "Prompt demo", message = "Type 3-8 characters. This mimics a controlled prompt instead of delegating to a native browser API.", prompt_value = "explore-react", notice = "Opened prompt overlay demo."))
  else if payload == dialog_open_payload("dialog") then
    Just(open_dialog_demo(owner, kind = Dialog_dialog, title = "Dialog demo", message = "This is a centered custom dialog body, closer to an explore-react modal component than a native browser API.", notice = "Opened dialog overlay demo."))
  else if payload == dialog_open_payload("drawer") then
    Just(open_dialog_demo(owner, kind = Dialog_drawer, title = "Drawer demo", message = "This side sheet keeps the background visible while secondary actions happen in a dedicated panel.", notice = "Opened drawer overlay demo."))
  else Nothing

pub fun dialog_demo_case(owner : model) : app_view vnode
  val current = owner.dialog
  val open_alert = on_local_click("open-alert", fn(next_owner : model) open_dialog_demo(next_owner, kind = Dialog_alert, title = "Alert demo", message = "A controlled alert surface rendered inside the app tree, similar to the explore-react demos in the MoonBit and Rust implementations.", notice = "Opened alert overlay demo."))
  val open_prompt = on_local_click("open-prompt", fn(next_owner : model) open_dialog_demo(next_owner, kind = Dialog_prompt, title = "Prompt demo", message = "Type 3-8 characters. This mimics a controlled prompt instead of delegating to a native browser API.", prompt_value = "explore-react", notice = "Opened prompt overlay demo."))
  val open_dialog_listener = on_local_click("open-dialog", fn(next_owner : model) open_dialog_demo(next_owner, kind = Dialog_dialog, title = "Dialog demo", message = "This is a centered custom dialog body, closer to an explore-react modal component than a native browser API.", notice = "Opened dialog overlay demo."))
  val open_drawer = on_local_click("open-drawer", fn(next_owner : model) open_dialog_demo(next_owner, kind = Dialog_drawer, title = "Drawer demo", message = "This side sheet keeps the background visible while secondary actions happen in a dedicated panel.", notice = "Opened drawer overlay demo."))
  div([
    div([
      button("Try Alert", class = "button", click = open_alert),
      button("Try Prompt", class = "button", click = open_prompt),
      button("Try Dialog", class = "button button-primary", click = open_dialog_listener),
      button("Try Drawer", class = "button button-danger", click = open_drawer),
    ], class = "button-row"),
    div([
      div([
        strong("Overlay state"),
        p("kind: " ++ (if dialog_is_open(current) then current.kind.show_kind else "<none>"), class = "mono"),
        p("result: " ++ current.result_note, class = "mono"),
      ], class = "mini-panel stack"),
      div([
        strong("Dialog activity"),
        if is-empty(current.activity_log) then p("No overlay interactions yet.", class = "empty") else ul(map-indexed(current.activity_log, fn(index, line) li_text(line, key = "dialog-log-" ++ index.show, class = "activity-item")), class = "activity-list dialog-log-list"),
      ], class = "mini-panel stack"),
    ], class = "preview-grid"),
  ], class = "stack")

fun prompt_body(current : dialog_demo, prompt_input_listener : listener, submit_enter_listener : listener) : <div> list<vnode>
  [
    input_text(current.prompt_value, key = "dialog-prompt-input", class = "input", data_effect = dialog_prompt_focus_marker(), input = prompt_input_listener, enter = submit_enter_listener, placeholder = "3-8 chars"),
    if current.prompt_error == "" then p("Validation runs on submit, similar to the other explore-react prompt demos.", class = "case-detail") else p(current.prompt_error, class = "dialog-error"),
  ]

fun dialog_custom_body(label : string, current : dialog_demo) : <div> list<vnode>
  [
    p(current.message, class = "case-detail"),
    div([
      div([
        strong("Intentional layout"),
        p("The dialog demo keeps open and overlay actions inside local listeners, even though the overlay still renders globally in the app tree.", class = "mono"),
      ], class = "mini-panel stack"),
      div([
        strong("Last result"),
        p(current.result_note, class = "mono"),
      ], class = "mini-panel stack"),
    ], class = "preview-grid"),
  ]

fun overlay_spec(current : dialog_demo, prompt_input_listener : listener, submit_enter_listener : listener) : <div> dialog_overlay_spec
  match current.kind
    Dialog_prompt -> Dialog_overlay_spec("dialog-overlay-shell dialog-overlay-center", "prompt-overlay", "dialog-overlay-card", prompt_body(current, prompt_input_listener, submit_enter_listener), Footer_submit("Submit"))
    Dialog_alert -> Dialog_overlay_spec("dialog-overlay-shell dialog-overlay-center", "alert-overlay", "dialog-overlay-card", [p("This alert is state-driven and lives inside the same VDOM tree as the rest of the app.", class = "case-detail")], Footer_primary_only("I read it"))
    Dialog_dialog -> Dialog_overlay_spec("dialog-overlay-shell dialog-overlay-center", "dialog-overlay", "dialog-overlay-card", dialog_custom_body("dialog-custom", current), Footer_primary_with_cancel("Run dialog action"))
    _ -> Dialog_overlay_spec("dialog-overlay-shell dialog-overlay-drawer", "drawer-overlay", "dialog-overlay-card drawer-overlay-card", dialog_custom_body("drawer-custom", current), Footer_primary_with_cancel("Commit drawer"))

pub fun dialog_overlay(owner : model) : app_view vnode
  feature_root("overlays", "dialog") {
    val current = owner.dialog
    val close_overlay = on_local_click("close-overlay", fn(next_owner : model) apply_dialog_update(next_owner, close_dialog(next_owner.dialog, result_note = "Overlay dismissed.", notice = "Closed the overlay demo.", log_line = "[close] overlay dismissed")))
    val primary_action = on_local_click("primary-action", fn(next_owner : model) dialog_primary_action(next_owner))
    val submit_action = on_local_click("submit-action", fn(next_owner : model) prompt_submit(next_owner))
    val submit_enter = on_local_enter("submit-action", fn(next_owner : model) prompt_submit(next_owner))
    val prompt_input = on_local_input("prompt-input", fn(value, next_owner : model) next_owner(dialog = update_dialog_prompt(next_owner.dialog, value)))
    state_effect(name = "focus-dialog", deps = [current.kind.show_kind, current.prompt_error, current.title], action = fn() {
      if dialog_is_open(current) then dom_focus(dialog_focus_marker(current)) else ()
    })
    dialog/render_dialog_overlay(current, spec = overlay_spec(current, prompt_input, submit_enter), controls = Dialog_overlay_controls(close_overlay, primary_action, submit_action))
  }
