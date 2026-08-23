module demo/tests/statecases

import demo/tests/support
import demo/lab/state
import demo/todo/state
import explore/react/core
import explore/react/state

pub fun state_tree_test() : <div> test_result
  val incident_scope = "lab/incidents/101"
  val tree = assoc_named_local_state(
    assoc_named_local_state(Nil, incident_scope, "draft", "Shift traffic to backup POP."),
    incident_scope,
    "expanded",
    True)
  val draft = read_named_local_state(tree, incident_scope, "draft", "")
  val expanded = read_named_local_state(tree, incident_scope, "expanded", False)
  val named_hook_state = named_local_state_path("todo/tasks/2", "draft")
  val named_hook_effect = named_local_effect_path("todo/effects", "notice-pulse")
  Test_result("State tree semantic local state", "draft=" ++ draft ++ ", expanded=" ++ expanded.show ++ ", hook-state=" ++ named_hook_state ++ ", hook-effect=" ++ named_hook_effect, draft == "Shift traffic to backup POP." && expanded && named_hook_state == "todo/tasks/2/state/draft" && named_hook_effect == "todo/effects/effect/notice-pulse")

pub fun component_key_canonicalization_test() : <div> test_result
  val numeric_path = component_local_path("tests", "1")
  val underscored_path = component_local_path("tests", "_1")
  val empty_path = component_local_path("tests", "")
  val old_empty_literal_path = component_local_path("tests", "slot")
  val escaped_empty_literal_path = component_local_path("tests", "__")
  val special_key = "a/b\"c\\d"
  val special_path = component_local_path("feature", special_key)
  val special_node_key = feature_node_key(group = "feature", key = special_key)
  val special_marker = feature_dom_marker(group = "feature", key = special_key, name = "draft")
  val composite_keys_distinct =
    feature_node_key(group = "a-b", key = "c") !=
    feature_node_key(group = "a", key = "b-c")
  val legacy_task_path = component_child_path(component_local_path("todo", "panel"), "tasks", "2")
  val safe_names_stable =
    component_local_path("todo", "panel") == "todo/panel" &&
    feature_node_key(group = "todo", key = "panel") == "todo" &&
    feature_dom_marker(group = "todo", key = "panel", name = "draft") == "draft"
  val collision_free =
    numeric_path == "tests/_1" &&
    underscored_path == "tests/___1" &&
    numeric_path != underscored_path &&
    empty_path == "tests/__" &&
    empty_path != old_empty_literal_path &&
    empty_path != escaped_empty_literal_path
  val special_names_safe =
    special_path == "feature/a%2Fb%22c%5Cd" &&
    special_node_key == "feature:a%2Fb%22c%5Cd" &&
    special_marker == special_node_key ++ ":draft"
  Test_result(
    "Component keys use one collision-free canonical form",
    "numeric=" ++ numeric_path ++ ", underscore=" ++ underscored_path ++ ", empty=" ++ empty_path ++ ", special=" ++ special_path ++ ", marker=" ++ special_marker,
    collision_free && composite_keys_distinct && special_names_safe && safe_names_stable && legacy_task_path == "todo/panel/tasks/_2")

pub fun generic_state_codec_test() : <div> test_result
  val scope_name = component_local_path("tests", "implicit-codec")
  val ((draft, open_before), next_tree, _pending_effects) = run_local_state(Nil, fn() {
    feature_root(group = "tests", key = "implicit-codec", render = fn() {
      val (draft0, set_draft) = state_pair(name = "draft", initial = "hello")
      val (open0, set_open) = state_pair(name = "open", initial = False)
      set_draft(draft0 ++ " world")
      set_open(not(open0))
      (draft0, open0)
    })
  })
  val draft_after = read_named_local_state(next_tree, scope_name, "draft", "")
  val open_after = read_named_local_state(next_tree, scope_name, "open", False)
  Test_result("Implicit use_state codec", "draft=" ++ draft ++ ", open-before=" ++ open_before.show ++ ", open-after=" ++ open_after.show, draft == "hello" && not(open_before) && draft_after == "hello world" && open_after)

pub fun malformed_store_payload_test() : <div> test_result
  val todo_scope = "tests/malformed-todo"
  val todo_initial = Task_editor_state(False, "todo fallback")
  val todo_tree = [State_entry(named_local_state_path(todo_scope, "editor"), "todo/task-editor", 1, "")]
  val todo_state = read_store_state(todo_tree, todo_scope, task_editor_store, todo_initial)
  val todo_action_safe = match decode_store_action(task_editor_store, State_action(todo_scope, "todo/task-editor-action", 1, ""))
    Nothing -> True
    _ -> False
  val lab_scope = "tests/malformed-lab"
  val lab_initial = Incident_local_state(False, "lab fallback")
  val lab_tree = [State_entry(named_local_state_path(lab_scope, "incident"), "lab/incident-local", 1, "")]
  val lab_state = read_store_state(lab_tree, lab_scope, incident_local_store, lab_initial)
  val lab_action_safe = match decode_store_action(incident_local_store, State_action(lab_scope, "lab/incident-local-action", 1, ""))
    Nothing -> True
    _ -> False
  val malformed_snapshot_safe = is-empty(decode_state_snapshot("path|schema|1|bad%"))
  val empty_snapshot_payload_valid = length(decode_state_snapshot("path|schema|1|")) == 1
  val passed = todo_state.draft == "todo fallback" && lab_state.draft == "lab fallback" && todo_action_safe && lab_action_safe && malformed_snapshot_safe && empty_snapshot_payload_valid
  Test_result("Malformed store payloads are rejected", "todo=" ++ todo_action_safe.show ++ ", lab=" ++ lab_action_safe.show ++ ", snapshot=" ++ malformed_snapshot_safe.show, passed)

pub fun auto_hook_scope_test() : <div> test_result
  val left_scope = component_local_path("tests", "left")
  val right_scope = component_local_path("tests", "right")
  val ((left_before, right_before), next_tree, pending_effects) = run_local_state(Nil, fn() {
    val left_result = feature_root(group = "tests", key = "left", render = fn() {
      val (draft, set_draft) = state_pair(name = "draft", initial = "left")
      set_draft(draft ++ " next")
      draft
    })
    val right_result = feature_root(group = "tests", key = "right", render = fn() {
      val draft = state(name = "draft", initial = "right")
      state_effect(name = "record-draft", deps = [draft], action = fn() ())
      draft
    })
    (left_result, right_result)
  })
  val left_after = read_named_local_state(next_tree, left_scope, "draft", "")
  val right_after = read_named_local_state(next_tree, right_scope, "draft", "")
  val effect_path = named_local_effect_path(right_scope, "record-draft")
  val has_effect = match pending_effects {
    Nil -> False
    Cons(item, _rest) -> scheduled_effect/path(item) == effect_path
  }
  Test_result(
    "Auto hook scopes stay isolated",
    "left-before=" ++ left_before ++ ", right-before=" ++ right_before ++ ", left-after=" ++ left_after ++ ", right-after=" ++ right_after ++ ", effect=" ++ has_effect.show,
    left_before == "left" && right_before == "right" && left_after == "left next" && right_after == "" && has_effect)

pub fun listener_registry_guard_test() : <div> test_result
  val handler_path = named_local_listener_path("guard/demo", Click_event, "save")
  val (_unit, registry) = run_event_registry(fn() {
    on_scoped_click("guard/demo", "save", "save", fn(owner : string) owner)
    on_scoped_click("guard/demo", "save", "save", fn(owner : string) owner ++ "!")
    on_scoped_click("guard/demo", "save", "danger-remove", fn(owner : string) owner)
    ()
  })
  val registered_count = count_registered_clicks(registry)
  val warning_count = length(event_registry/warnings(registry))
  val final_semantic = match find_registered_click(registry, handler_path)
    Just(found) -> registered_click/semantic_name(found)
    Nothing -> "missing"
  Test_result(
    "Listener registry guards",
    "registered=" ++ registered_count.show ++ ", warnings=" ++ warning_count.show ++ ", semantic=" ++ final_semantic,
    registered_count == 1 && warning_count == 2 && final_semantic == "danger-remove")

pub fun typed_action_listener_test() : <div> test_result
  val ((_listeners, _tree, _effects), registry) = run_event_registry(fn() run_local_state(Nil, fn() feature_root(group = "tests", key = "action-listeners", render = fn() {
    val click = on_action_click("add-two", action = 2, dispatch = fn(amount : int, owner : int) owner + amount)
    val enter = on_action_enter("add-three", action = 3, dispatch = fn(amount : int, owner : int) owner + amount)
    (click, enter)
  })))
  val click_result = match find_registered_click_by_semantic(registry, "add-two")
    Just(found) -> run_registered_click(found, 10)
    Nothing -> -1
  val enter_result = match find_registered_click_by_semantic(registry, "add-three")
    Just(found) -> run_registered_click(found, 10)
    Nothing -> -1
  Test_result(
    "Typed action listeners dispatch captured actions",
    "click=" ++ click_result.show ++ ", enter=" ++ enter_result.show ++ ", registered=" ++ count_registered_clicks(registry).show,
    click_result == 12 && enter_result == 13 && count_registered_clicks(registry) == 2)
