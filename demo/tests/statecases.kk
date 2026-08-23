module demo/tests/statecases

import demo/tests/support
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

pub fun generic_state_codec_test() : <div> test_result
  val ((draft, open_before), next_tree, _pending_effects) = run_local_state(Nil, fn() {
    component("implicit-codec", fn() {
      val (draft0, set_draft) = state_pair(name = "draft", initial = "hello")
      val (open0, set_open) = state_pair(name = "open", initial = False)
      set_draft(draft0 ++ " world")
      set_open(not(open0))
      (draft0, open0)
    })
  })
  val draft_after = read_named_local_state(next_tree, "implicit-codec", "draft", "")
  val open_after = read_named_local_state(next_tree, "implicit-codec", "open", False)
  Test_result("Implicit use_state codec", "draft=" ++ draft ++ ", open-before=" ++ open_before.show ++ ", open-after=" ++ open_after.show, draft == "hello" && not(open_before) && draft_after == "hello world" && open_after)

pub fun auto_hook_scope_test() : <div> test_result
  val ((left_before, right_before), next_tree, pending_effects) = run_local_state(Nil, fn() {
    val left_result = component("todo/tasks/7", fn() {
      val (draft, set_draft) = state_pair(name = "draft", initial = "left")
      set_draft(draft ++ " next")
      draft
    })
    val right_result = component("lab/incidents/11", fn() {
      val draft = state(name = "draft", initial = "right")
      state_effect(name = "record-draft", deps = [draft], action = fn() ())
      draft
    })
    (left_result, right_result)
  })
  val left_after = read_named_local_state(next_tree, "todo/tasks/7", "draft", "")
  val right_after = read_named_local_state(next_tree, "lab/incidents/11", "draft", "")
  val effect_path = named_local_effect_path("lab/incidents/11", "record-draft")
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
  val (_unit, duplicate_registry) = run_event_registry(fn() {
    on_scoped_click("guard/demo", "save", "save", fn(owner : string) owner)
    on_scoped_click("guard/demo", "save", "save", fn(owner : string) owner ++ "!")
    ()
  })
  val (_unit2, merged_left) = run_event_registry(fn() {
    on_scoped_click("guard/demo", "save", "save", fn(owner : string) owner)
    ()
  })
  val (_unit3, merged_right) = run_event_registry(fn() {
    on_scoped_click("guard/demo", "save", "danger-remove", fn(owner : string) owner)
    ()
  })
  val merged_registry = append_event_registries(merged_left, merged_right)
  val duplicate_count = count_registered_clicks(duplicate_registry)
  val duplicate_warnings = length(event_registry/warnings(duplicate_registry))
  val merged_warnings = length(event_registry/warnings(merged_registry))
  val merged_semantic = match find_registered_click(merged_registry, handler_path)
    Just(found) -> registered_click/semantic_name(found)
    Nothing -> "missing"
  Test_result(
    "Listener registry guards",
    "duplicate-count=" ++ duplicate_count.show ++ ", duplicate-warnings=" ++ duplicate_warnings.show ++ ", merged-warnings=" ++ merged_warnings.show ++ ", semantic=" ++ merged_semantic,
    duplicate_count == 1 && duplicate_warnings == 1 && merged_warnings == 1 && merged_semantic == "danger-remove")
