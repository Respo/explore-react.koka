module demo/tests/basics

import library/bridge
import library/route
import demo/model
import demo/runtimebridge
import demo/seed
import demo/tests/appharness
import demo/tests/support
import demo/todo/events
import demo/todo/state
import demo/todopanel
import explore/react/core
import explore/react/renderer
import explore/react/state

fun timer_logic() : <browser_host> string
  wait_ms(20)
  wait_ms(20)
  wait_ms(40)
  "timer-ready"

pub fun component_render_test() : <div> test_result
  val html = render_node("0", button(props(class = "demo-button"), on(click = click_listener("run-sample")), "Run"))
  val expected = "<button data-kpath=\"0\" class=\"demo-button\" data-k-click=\"run-sample\">Run</button>"
  Test_result("Component render snapshot", if html == expected then "Stable HTML output for a small component." else html, html == expected)

pub fun confirm_decline_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val h0 = todo_harness(initial_model())
  val remove_payload = keyed_button_payload(h0.tree, "1", "Remove")
  val next = todo_harness_click_payload(h0, remove_payload).owner
  Test_result("Confirm decline keeps state", next.notice, length(next.tasks) == 3)

pub fun confirm_accept_test() : <div> test_result
  with with_test_browser(True, "T+0")
  val h0 = todo_harness(initial_model())
  val remove_payload = keyed_button_payload(h0.tree, "1", "Remove")
  val next = todo_harness_click_payload(h0, remove_payload).owner
  Test_result("Confirm accept removes task", "Remaining tasks: " ++ length(next.tasks).show, length(next.tasks) == 2)

pub fun ambient_filter_test() : <div> test_result
  val base = initial_model().tasks
  val active_count = length(tasks_for("active", base))
  val done_count = length(tasks_for("done", base))
  Test_result("Ambient filter previews", "active=" ++ active_count.show ++ ", done=" ++ done_count.show, active_count == 2 && done_count == 1)

pub fun registered_input_handler_test() : <div> test_result
  val target_id = todo_panel_listener_path(Input_event, "draft-input")
  val (next_item, next_runtime_tree, _panel_node, _effects, handlers) = run_todo_panel(initial_model(), Nil)
  match find_registered_input(handlers, target_id)
    Just(found_input) -> {
      val (updated, _updated_runtime_tree) = run_with_runtime_tree(target_id, next_item, next_runtime_tree, fn(current_owner) run_registered_input(found_input, "closure draft", current_owner))
      Test_result("Registered input handler updates draft", "inputs=" ++ count_registered_inputs(handlers).show ++ ", draft=" ++ updated.draft, updated.draft == "closure draft")
    }
    Nothing -> Test_result("Registered input handler updates draft", target_id ++ " missing", False)

pub fun registered_click_handler_test() : <div> test_result
  with with_test_browser(False, "10:00:00")
  val initial_harness = todo_harness(initial_model())
  val edit_payload = keyed_button_payload(initial_harness.tree, "2", "Edit")
  val started_harness = todo_harness_click_payload(initial_harness, edit_payload)
  val started = started_harness.owner
  val panel_node = started_harness.tree
  val handlers = started_harness.registry
  val cancel_payload = keyed_button_payload(panel_node, "2", "Cancel")
  val updated = todo_harness_click_payload(started_harness, cancel_payload).owner
  val updated_task = match find(updated.tasks, fn(task_item) 2 == task/id(task_item))
    Just(found) -> found
    Nothing -> Task(2, "missing", False)
  val editor_state = snapshot_task_editor(todo_harness_click_payload(started_harness, cancel_payload).runtime_tree, updated_task)
  val in_registry = match find_registered_click(handlers, cancel_payload)
    Just(_) -> True
    Nothing -> False
  Test_result(
    "Rendered cancel payload stays local",
    "payload=" ++ cancel_payload ++ ", local=" ++ in_registry.show ++ ", notice=" ++ updated.notice,
    cancel_payload == task_listener_path(updated_task, Click_event, "cancel-edit") && in_registry && not(task_editor_state/editing(editor_state)) && updated.notice == "Cancelled local task edit.")

pub fun timer_simulation_test() : <div> test_result
  val (label, waits) = capture_waits(fn() timer_logic())
  val total = sum(waits)
  val steps = length(waits)
  Test_result("Timer simulation", steps.show ++ " waits / " ++ total.show ++ "ms / result=" ++ label, label == "timer-ready" && steps == 3 && total == 80)

pub fun route_subroute_normalization_test() : <div> test_result
  with with_test_browser(False, "10:00:00")
  val lab_route = match handle_route_click(route_action_payload(Navigate("lab-search")), initial_model())
    Just(result) -> result.route_name
    Nothing -> "missing"
  val effects_route = match handle_route_click(route_action_payload(Navigate("effects-dialogs")), initial_model())
    Just(result) -> result.route_name
    Nothing -> "missing"
  val legacy_lab = normalize_route("lab")
  val legacy_effects = normalize_route("effects")
  Test_result(
    "Route subpages normalize",
    "lab=" ++ lab_route ++ ", effects=" ++ effects_route ++ ", legacy=" ++ legacy_lab ++ "/" ++ legacy_effects,
    lab_route == "lab-search" && effects_route == "effects-dialogs" && legacy_lab == "lab-board" && legacy_effects == "effects-core")

pub fun route_bar_click_is_local_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val h0 = app_harness(initial_model())
  val checks_payload = button_payload_by_text(h0.tree, "Checks")
  val in_registry = match find_registered_click(h0.registry, checks_payload)
    Just(_) -> True
    Nothing -> False
  val h1 = app_harness_click_payload(h0, checks_payload)
  Test_result(
    "Route bar uses local listener",
    "payload=" ++ checks_payload ++ ", route=" ++ h1.owner.route_name ++ ", local=" ++ in_registry.show,
    checks_payload == component_listener_path("app", "root", Click_event, "nav-checks") && in_registry && h1.owner.route_name == "checks")

// --- Component harness tests ---
// These tests exercise components by navigating the vnode tree, reading event
// attributes, and firing handlers through the registry - mirroring how the browser
// delegates DOM events, without needing a real DOM.

// Verify that a button's data-k-click value is enough to resolve a local todo handler.
pub fun vnode_click_payload_matches_route_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val initial_harness = todo_harness(initial_model())
  val edit_payload = keyed_button_payload(initial_harness.tree, "2", "Edit")
  val editing_harness = todo_harness_click_payload(initial_harness, edit_payload)
  val editing = editing_harness.owner
  val tree = editing_harness.tree
  val registry = editing_harness.registry
  val cancel_node_payload = keyed_button_payload(tree, "2", "Cancel")
  val routed = todo_harness_click_payload(editing_harness, cancel_node_payload).owner
  val editor_state = match find(routed.tasks, fn(item) 2 == task/id(item))
    Just(item) -> snapshot_task_editor(todo_harness_click_payload(editing_harness, cancel_node_payload).runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  val in_registry = match find_registered_click(registry, cancel_node_payload)
    Just(_) -> True
    Nothing -> False
  val target_task = match find(routed.tasks, fn(item) 2 == task/id(item))
    Just(found) -> found
    Nothing -> Task(2, "missing", False)
  Test_result(
    "Vnode click payload matches route",
    "payload=" ++ cancel_node_payload ++ ", local=" ++ in_registry.show ++ ", notice=" ++ routed.notice,
    cancel_node_payload == task_listener_path(target_task, Click_event, "cancel-edit") && in_registry && routed.notice == "Cancelled local task edit." && not(task_editor_state/editing(editor_state)))

// Verify that firing the local cancel semantic through the harness updates the owner.
pub fun harness_cancel_edit_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val h0 = todo_harness(initial_model())
  val start_payload = keyed_button_payload(h0.tree, "2", "Edit")
  val editing_harness = todo_harness_click_payload(h0, start_payload)
  val cancel_payload = keyed_button_payload(editing_harness.tree, "2", "Cancel")
  val h1 = todo_harness_click_payload(editing_harness, cancel_payload)
  val editor_state = match find(h1.owner.tasks, fn(item) 2 == task/id(item))
    Just(item) -> snapshot_task_editor(h1.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  Test_result(
    "Harness cancel via click payload",
    "notice=" ++ h1.owner.notice ++ ", editing=" ++ task_editor_state/editing(editor_state).show,
    h1.owner.notice == "Cancelled local task edit." && not(task_editor_state/editing(editor_state)))

// Verify that an input event fired via harness updates the model and is reflected
// in the re-rendered vnode's value attribute.
pub fun harness_draft_input_test() : <div> test_result
  val h0 = todo_harness(initial_model())
  val h1 = harness_fire_named_input(h0, "draft-input", "typed via harness", todo_harness_render)
  val input_value = match vnode_find_attr_value(h1.tree, "data-k-effect", "draft")
    Just(node) -> vnode_get_attr(node, "value")
    Nothing -> "node-missing"
  Test_result(
    "Harness input updates model and vnode",
    "draft=" ++ h1.owner.draft ++ ", input-value=" ++ input_value,
    h1.owner.draft == "typed via harness" && input_value == "typed via harness")

// Multi-step: type into draft, then fire cancel on a task being edited.
// Verifies that two sequential harness steps compose correctly.
pub fun harness_multi_step_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val base_harness = todo_harness(initial_model())
  val h0 = todo_harness_click_payload(base_harness, keyed_button_payload(base_harness.tree, "2", "Edit"))
  // Step 1: type into the panel draft field
  val h1 = harness_fire_named_input(h0, "draft-input", "step1 draft", todo_harness_render)
  // Step 2: cancel the task edit via click payload
  val h2 = todo_harness_click_payload(h1, keyed_button_payload(h1.tree, "2", "Cancel"))
  val editor_state = match find(h2.owner.tasks, fn(item) 2 == task/id(item))
    Just(item) -> snapshot_task_editor(h2.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  Test_result(
    "Harness multi-step input then click",
    "draft=" ++ h2.owner.draft ++ ", notice=" ++ h2.owner.notice ++ ", editing=" ++ task_editor_state/editing(editor_state).show,
    h2.owner.draft == "step1 draft" && h2.owner.notice == "Cancelled local task edit." && not(task_editor_state/editing(editor_state)))
