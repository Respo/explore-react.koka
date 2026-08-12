module demo/tests/dialogcases

import demo/tests/appharness
import demo/dialogs
import demo/effectspanel
import demo/model
import demo/seed
import demo/tests/support
import demo/view
import library/bridge
import library/dialog
import library/route
import explore/react/core
import explore/react/state

pub fun dialog_alert_open_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val h0 = app_harness(initial_model()(route_name = normalize_route("effects-dialogs")))
  val alert_payload = button_payload_by_text(h0.tree, "Try Alert")
  val in_registry = match find_registered_click(h0.registry, alert_payload)
    Just(_) -> True
    Nothing -> False
  val current = app_harness_click_payload(h0, alert_payload).owner.dialog
  Test_result(
    "Dialog alert opens overlay",
    "kind=" ++ current.kind.show_kind ++ ", title=" ++ current.title ++ ", local=" ++ in_registry.show,
    (match current.kind { Dialog_alert -> True; _ -> False }) && current.title == "Alert demo" && in_registry && alert_payload == effects_dialog_demo_listener_path(Click_event, "open-alert"))

pub fun dialog_prompt_validation_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val (opened, _open_audits) = capture_dialog_click(dialog_base_model(), dialog_open_payload("prompt"))
  val h0 = app_harness(opened)
  val prompt_channel = input_channel_by_effect_marker(h0.tree, dialog_prompt_focus_marker())
  val typed_h = app_harness_input_channel(h0, prompt_channel, "xy")
  val submit_payload = button_payload_by_text(typed_h.tree, "Submit")
  val in_input_registry = match find_registered_input(h0.registry, prompt_channel)
    Just(_) -> True
    Nothing -> False
  val in_click_registry = match find_registered_click(typed_h.registry, submit_payload)
    Just(_) -> True
    Nothing -> False
  val current = app_harness_click_payload(typed_h, submit_payload).owner.dialog
  Test_result(
    "Dialog prompt validates input",
    "error=" ++ current.prompt_error ++ ", local-input=" ++ in_input_registry.show ++ ", local-submit=" ++ in_click_registry.show,
    (match current.kind { Dialog_prompt -> True; _ -> False }) && current.prompt_error == "Use 3-8 characters." && in_input_registry && in_click_registry && prompt_channel == component_listener_path("overlays", "dialog", Input_event, "prompt-input") && submit_payload == component_listener_path("overlays", "dialog", Click_event, "submit-action"))

pub fun dialog_prompt_submit_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val (opened, _open_audits) = capture_dialog_click(dialog_base_model(), dialog_open_payload("prompt"))
  val h0 = app_harness(opened)
  val prompt_channel = input_channel_by_effect_marker(h0.tree, dialog_prompt_focus_marker())
  val typed_h = app_harness_input_channel(h0, prompt_channel, "bridge")
  val submit_payload = button_payload_by_text(typed_h.tree, "Submit")
  val current = app_harness_click_payload(typed_h, submit_payload).owner.dialog
  Test_result(
    "Dialog prompt submits and closes",
    "kind=" ++ current.kind.show_kind ++ ", result=" ++ current.result_note ++ ", payload=" ++ submit_payload,
    not(dialog_is_open(current)) && current.result_note == "Prompt submitted: bridge" && submit_payload == component_listener_path("overlays", "dialog", Click_event, "submit-action"))

pub fun dialog_prompt_focus_effect_test() : <div> test_result
  val (opened, _open_audits) = capture_dialog_click(dialog_base_model(), dialog_open_payload("prompt"))
  val (_next_item, overlay_node, effects, _handlers) = render_app(opened, Nil)
  Test_result(
    "Dialog prompt schedules focus effect",
    "effects=" ++ length(effects).show ++ ", marker=" ++ vnode_has_attr_value(overlay_node, "data-k-effect", "dialog-prompt-focus").show,
    any(effects, fn(item) scheduled_effect/path(item) == dialog_overlay_effect_path()) && vnode_has_attr_value(overlay_node, "data-k-effect", "dialog-prompt-focus"))

pub fun dialog_overlay_uses_runtime_tree_test() : <div> test_result
  val (opened, _open_audits) = capture_dialog_click(dialog_base_model(), dialog_open_payload("prompt"))
  val h0 = app_harness(opened)
  val in_runtime_tree = any(h0.runtime_tree, fn(item) state_entry/path(item) == dialog_overlay_effect_path())
  Test_result(
    "Dialog overlay uses runtime tree",
    "entries=" ++ count_entries(h0.runtime_tree).show ++ ", effect-in-tree=" ++ in_runtime_tree.show,
    in_runtime_tree)

pub fun dialog_drawer_action_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val (opened, _open_audits) = capture_dialog_click(dialog_base_model(), dialog_open_payload("drawer"))
  val h0 = app_harness(opened)
  val primary_payload = button_payload_by_text(h0.tree, "Commit drawer")
  val in_registry = match find_registered_click(h0.registry, primary_payload)
    Just(_) -> True
    Nothing -> False
  val closed = app_harness_click_payload(h0, primary_payload).owner
  val opened_kind = opened.dialog.kind
  val current = closed.dialog
  Test_result(
    "Dialog drawer action closes overlay",
    "opened=" ++ opened_kind.show_kind ++ ", kind=" ++ current.kind.show_kind ++ ", result=" ++ current.result_note ++ ", local=" ++ in_registry.show,
    (match opened_kind { Dialog_drawer -> True; _ -> False }) && not(dialog_is_open(current)) && current.result_note == "Drawer action completed." && in_registry && primary_payload == component_listener_path("overlays", "dialog", Click_event, "primary-action"))