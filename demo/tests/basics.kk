module demo/tests/basics

import library/bridge
import library/route
import demo/model
import demo/runtimeframe
import demo/seed
import demo/tests/appharness
import demo/tests/support
import demo/todo/events
import demo/todo/state
import demo/todo/view
import demo/todo/viewmodel
import explore/react/action
import explore/react/core
import explore/react/renderer
import explore/react/state

fun timer_logic() : <browser_host> string
  wait_ms(20)
  wait_ms(20)
  wait_ms(40)
  "timer-ready"

pub fun component_render_test() : <div> test_result
  val html = render_node("0", button("Run", class = "demo-button", click = click_listener("run-sample")))
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
  with with_test_browser(False, "T+0")
  val h0 = todo_harness(initial_model())
  val handlers = h0.registry
  match find_registered_input_by_semantic(handlers, "draft-input")
    Just(found_input) -> {
      val updated = run_runtime_action(current_runtime_frame(h0.owner, h0.runtime_tree), fn(current_owner) run_registered_input(found_input, "closure draft", current_owner)).owner
      Test_result("Registered input handler updates draft", "inputs=" ++ count_registered_inputs(handlers).show ++ ", draft=" ++ updated.draft, updated.draft == "closure draft")
    }
    Nothing -> Test_result("Registered input handler updates draft", "draft-input missing", False)

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
  val editor_state = inspect_task_editor(todo_harness_click_payload(started_harness, cancel_payload).runtime_tree, updated_task)
  val in_registry = match find_registered_click(handlers, cancel_payload)
    Just(_) -> True
    Nothing -> False
  Test_result(
    "Rendered cancel payload stays local",
    "payload=" ++ cancel_payload ++ ", local=" ++ in_registry.show ++ ", notice=" ++ updated.notice,
    cancel_payload == named_local_listener_path(component_child_path(component_local_path("todo", "panel"), "tasks", task/id(updated_task).show), Click_event, "cancel-edit") && in_registry && not(task_editor_state/editing(editor_state)) && updated.notice == "Cancelled local task edit.")

pub fun timer_simulation_test() : <div> test_result
  val (label, waits) = capture_waits(fn() timer_logic())
  val total = sum(waits)
  val steps = length(waits)
  Test_result("Timer simulation", steps.show ++ " waits / " ++ total.show ++ "ms / result=" ++ label, label == "timer-ready" && steps == 3 && total == 80)

pub fun route_subroute_normalization_test() : <div> test_result
  with with_test_browser(False, "10:00:00")
  val (routes, actions) = capture_actions(fn() {
    val lab_route = match handle_route_click(route_action_payload(Navigate("lab-search")), initial_model())
      Just(result) -> result.route_name
      Nothing -> "missing"
    val effects_route = match handle_route_click(route_action_payload(Navigate("effects-dialogs")), initial_model())
      Just(result) -> result.route_name
      Nothing -> "missing"
    (lab_route, effects_route)
  })
  val (lab_route, effects_route) = routes
  val legacy_lab = normalize_route("lab")
  val legacy_effects = normalize_route("effects")
  val observed = match actions
    [lab_action, effects_action] -> lab_action.schema == "app/route-action" && effects_action.schema == "app/route-action"
    _ -> False
  Test_result(
    "Route subpages normalize",
    "lab=" ++ lab_route ++ ", effects=" ++ effects_route ++ ", legacy=" ++ legacy_lab ++ "/" ++ legacy_effects,
    lab_route == "lab-search" && effects_route == "effects-dialogs" && legacy_lab == "lab-board" && legacy_effects == "effects-core" && observed)

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

pub fun app_feature_registry_test() : <div> test_result
  val registry = app_harness(initial_model()).registry
  val shell_path = component_listener_path("app", "root", Click_event, "nav-checks")
  val todo_path = component_listener_path("todo", "panel", Click_event, "add-task")
  val lab_path = component_listener_path("lab", "panel", Click_event, "load-board")
  val shell_registered = match find_registered_click(registry, shell_path) { Just(_) -> True; Nothing -> False }
  val todo_registered = match find_registered_click(registry, todo_path) { Just(_) -> True; Nothing -> False }
  val lab_registered = match find_registered_click(registry, lab_path) { Just(_) -> True; Nothing -> False }
  Test_result(
    "App runner collects feature components",
    "shell=" ++ shell_registered.show ++ ", todo=" ++ todo_registered.show ++ ", lab=" ++ lab_registered.show ++ ", warnings=" ++ registry.warnings.length.show,
    shell_registered && todo_registered && lab_registered && is-empty(registry.warnings))

fun count_vnode_attr_values(nodes : list<vnode>, name : string, value : string) : <div> int
  match nodes
    Nil -> 0
    Cons(node, rest) ->
      (if vnode_get_attr(node, name) == value then 1 else 0) +
      count_vnode_attr_values(vnode/children(node), name, value) +
      count_vnode_attr_values(rest, name, value)

fun todo_feature_pair_render(frame : runtime_frame) : <div> component_harness
  val (next_frame, tree, effects, registry) = run_runtime_render(frame, fn(owner) run_stateful_component(owner, fn(current) div([
    todo_panel(todo_panel_state_of(current), key = "left"),
    todo_panel(todo_panel_state_of(current), key = "right"),
  ])))
  Component_harness(runtime_frame/owner(next_frame), tree, effects, registry, runtime_frame/runtime_tree(next_frame))

pub fun feature_component_key_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val base = initial_model()
  val target = match find(base.tasks, fn(item) task/id(item) == 2)
    Just(item) -> item
    Nothing -> Task(2, "missing", False)
  val initial_editor = Task_editor_state(False, target.title)
  val left_scope = component_child_path(component_local_path("todo", "left"), "tasks", task/id(target).show)
  val right_scope = component_child_path(component_local_path("todo", "right"), "tasks", task/id(target).show)
  val default_scope = component_child_path(component_local_path("todo", "panel"), "tasks", task/id(target).show)
  val left_edit = named_local_listener_path(left_scope, Click_event, "start-edit")
  val right_edit = named_local_listener_path(right_scope, Click_event, "start-edit")
  val left_input = named_local_listener_path(left_scope, Input_event, "draft-input")
  val left_save = named_local_listener_path(left_scope, Click_event, "save-edit")

  val h0 = todo_feature_pair_render(current_runtime_frame(base, Nil))
  val h1 = harness_fire_click_payload(h0, left_edit, todo_feature_pair_render)
  val left_started = read_store_state(h1.runtime_tree, left_scope, task_editor_store, initial_editor)
  val right_before = read_store_state(h1.runtime_tree, right_scope, task_editor_store, initial_editor)
  val default_untouched = not(any(h1.runtime_tree, fn(entry) state_entry/path(entry) == named_local_state_path(default_scope, "editor")))

  val h2 = harness_fire_input_channel(h1, left_input, "left-only title", todo_feature_pair_render)
  val left_drafted = read_store_state(h2.runtime_tree, left_scope, task_editor_store, initial_editor)
  val h3 = harness_fire_click_payload(h2, right_edit, todo_feature_pair_render)
  val left_before_save = read_store_state(h3.runtime_tree, left_scope, task_editor_store, initial_editor)
  val right_started = read_store_state(h3.runtime_tree, right_scope, task_editor_store, initial_editor)
  val h4 = harness_fire_click_payload(h3, left_save, todo_feature_pair_render)
  val left_saved = read_store_state(h4.runtime_tree, left_scope, task_editor_store, initial_editor)
  val right_preserved = read_store_state(h4.runtime_tree, right_scope, task_editor_store, initial_editor)
  val default_still_untouched = not(any(h4.runtime_tree, fn(entry) state_entry/path(entry) == named_local_state_path(default_scope, "editor")))
  val saved_title = match find(h4.owner.tasks, fn(item) task/id(item) == 2)
    Just(item) -> item.title
    Nothing -> "missing"

  val left_registered = match find_registered_click(h0.registry, component_listener_path("todo", "left", Click_event, "add-task")) { Just(_) -> True; Nothing -> False }
  val right_registered = match find_registered_click(h0.registry, component_listener_path("todo", "right", Click_event, "add-task")) { Just(_) -> True; Nothing -> False }
  val left_effect = any(h0.effects, fn(item) scheduled_effect/path(item) == component_effect_path("todo", "left", "focus-draft"))
  val right_effect = any(h0.effects, fn(item) scheduled_effect/path(item) == component_effect_path("todo", "right", "focus-draft"))
  val markers_unique =
    count_vnode_attr_values([h0.tree], "data-k-effect", "todo:left:draft") == 1 &&
    count_vnode_attr_values([h0.tree], "data-k-effect", "todo:right:draft") == 1 &&
    count_vnode_attr_values([h0.tree], "data-k-effect", "todo:left-note") == 1 &&
    count_vnode_attr_values([h0.tree], "data-k-effect", "todo:right-note") == 1 &&
    count_vnode_attr_values([h3.tree], "data-k-effect", "todo:left:task-draft-2") == 1 &&
    count_vnode_attr_values([h3.tree], "data-k-effect", "todo:right:task-draft-2") == 1
  val default_harness = todo_harness(base)
  val default_compatible =
    vnode_has_attr_value(default_harness.tree, "data-k-effect", "draft") &&
    vnode_has_attr_value(default_harness.tree, "data-k-effect", "todo-note") &&
    (match vnode_find_key(default_harness.tree, "todo") { Just(_) -> True; Nothing -> False })
  val registries_clean =
    is-empty(h0.registry.warnings) && is-empty(h1.registry.warnings) &&
    is-empty(h2.registry.warnings) && is-empty(h3.registry.warnings) &&
    is-empty(h4.registry.warnings)
  Test_result(
    "Feature component keys isolate Todo actions",
    "started=" ++ left_started.editing.show ++ "/" ++ right_started.editing.show ++ ", drafts=" ++ left_before_save.draft ++ "/" ++ right_preserved.draft ++ ", saved=" ++ saved_title ++ ", markers=" ++ markers_unique.show,
    left_registered && right_registered && left_effect && right_effect &&
    left_started.editing && not(right_before.editing) && default_untouched && default_still_untouched &&
    left_drafted.draft == "left-only title" && left_before_save.draft == "left-only title" &&
    right_started.editing && right_started.draft == target.title &&
    not(left_saved.editing) && right_preserved.editing && right_preserved.draft == target.title &&
    saved_title == "left-only title" && markers_unique && default_compatible && registries_clean)

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
    Just(item) -> inspect_task_editor(todo_harness_click_payload(editing_harness, cancel_node_payload).runtime_tree, item)
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
    cancel_node_payload == named_local_listener_path(component_child_path(component_local_path("todo", "panel"), "tasks", task/id(target_task).show), Click_event, "cancel-edit") && in_registry && routed.notice == "Cancelled local task edit." && not(task_editor_state/editing(editor_state)))

// Verify that firing the local cancel semantic through the harness updates the owner.
pub fun harness_cancel_edit_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val h0 = todo_harness(initial_model())
  val start_payload = keyed_button_payload(h0.tree, "2", "Edit")
  val editing_harness = todo_harness_click_payload(h0, start_payload)
  val cancel_payload = keyed_button_payload(editing_harness.tree, "2", "Cancel")
  val h1 = todo_harness_click_payload(editing_harness, cancel_payload)
  val editor_state = match find(h1.owner.tasks, fn(item) 2 == task/id(item))
    Just(item) -> inspect_task_editor(h1.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  Test_result(
    "Harness cancel via click payload",
    "notice=" ++ h1.owner.notice ++ ", editing=" ++ task_editor_state/editing(editor_state).show,
    h1.owner.notice == "Cancelled local task edit." && not(task_editor_state/editing(editor_state)))

// Verify that an input event fired via harness updates the model and is reflected
// in the re-rendered vnode's value attribute.
pub fun harness_draft_input_test() : <div> test_result
  with with_test_browser(False, "T+0")
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
    Just(item) -> inspect_task_editor(h2.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  Test_result(
    "Harness multi-step input then click",
    "draft=" ++ h2.owner.draft ++ ", notice=" ++ h2.owner.notice ++ ", editing=" ++ task_editor_state/editing(editor_state).show,
    h2.owner.draft == "step1 draft" && h2.owner.notice == "Cancelled local task edit." && not(task_editor_state/editing(editor_state)))

pub fun app_runtime_preserves_child_store_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val h0 = app_harness(initial_model())
  val h1 = app_harness_click_payload(h0, keyed_button_payload(h0.tree, "2", "Edit"))
  val input_channel = keyed_input_channel(h1.tree, "2", "task-draft-2")
  val h2 = app_harness_input_channel(h1, input_channel, "draft through app runtime")
  val away = app_harness_click_payload(h2, button_payload_by_text(h2.tree, "Checks"))
  val restored = app_harness_click_payload(away, button_payload_by_text(away.tree, "Todo"))
  val editor_state = match find(restored.owner.tasks, fn(item) 2 == task/id(item))
    Just(item) -> inspect_task_editor(restored.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  Test_result(
    "App runtime preserves feature store",
    "route=" ++ restored.owner.route_name ++ ", editing=" ++ editor_state.editing.show ++ ", draft=" ++ editor_state.draft,
    restored.owner.route_name == "todo" && editor_state.editing && editor_state.draft == "draft through app runtime")
