module demo/tests/statecases

import demo/tests/support
import explore/react/core
import explore/react/state

pub fun state_tree_test() : <div> test_result
  val incident_base = "lab/incidents/101"
  val draft_slot = slot(incident_base, 0)
  val expanded_slot = named_slot(incident_base, "expanded")
  val named_hook_state = state_slot/path(hook_named_state_slot("todo/tasks/2", "draft"))
  val named_hook_effect = state_slot/path(hook_named_effect_slot("todo/effects", "notice-pulse"))
  val tree = assoc_slot_flag(assoc_slot_text(Nil, draft_slot, "Shift traffic to backup POP."), expanded_slot, True)
  val draft = slot_text(tree, draft_slot, "")
  val expanded = slot_flag(tree, expanded_slot, False)
  val normalized_name = state_slot/path(named_slot("todo/tasks/2", "7draft"))
  Test_result("State tree local state", "draft=" ++ draft ++ ", expanded=" ++ expanded.show ++ ", named=" ++ normalized_name ++ ", hook-state=" ++ named_hook_state ++ ", hook-effect=" ++ named_hook_effect, draft == "Shift traffic to backup POP." && expanded && normalized_name == "todo/tasks/2/_7draft" && named_hook_state == "todo/tasks/2/state/draft" && named_hook_effect == "todo/effects/effect/notice-pulse")

pub fun generic_state_codec_test() : <div> test_result
  val ((draft, open_before), next_tree, _pending_effects) = run_local_state(Nil, fn() {
    val (draft0, set_draft) = use_state_pair(text_state_codec, "hello")
    val (open0, set_open) = use_state_pair(flag_state_codec, False)
    set_draft(draft0 ++ " world")
    set_open(not(open0))
    (draft0, open0)
  })
  val draft_after = slot_text(next_tree, hook_state_slot("", 0), "")
  val open_after = slot_flag(next_tree, hook_state_slot("", 1), False)
  Test_result("Generic use_state codec", "draft=" ++ draft ++ ", open-before=" ++ open_before.show ++ ", open-after=" ++ open_after.show, draft == "hello" && not(open_before) && draft_after == "hello world" && open_after)

pub fun auto_hook_scope_test() : <div> test_result
  val ((left_before, right_before), next_tree, pending_effects) = run_local_state(Nil, fn() {
    val left_result = component("todo/tasks/7", fn() {
      val (draft, set_draft) = use_state_pair(text_state_codec, "left")
      set_draft(draft ++ " next")
      draft
    })
    val right_result = component("lab/incidents/11", fn() {
      val draft = use_state(text_state_codec, "right")
      use_effect([draft], fn() ())
      draft
    })
    (left_result, right_result)
  })
  val left_after = slot_text(next_tree, hook_state_slot("todo/tasks/7", 0), "")
  val right_after = slot_text(next_tree, hook_state_slot("lab/incidents/11", 0), "")
  val effect_path = state_slot/path(hook_effect_slot("lab/incidents/11", 0))
  val has_effect = match pending_effects {
    Nil -> False
    Cons(item, _rest) -> scheduled_effect/path(item) == effect_path
  }
  Test_result(
    "Auto hook scopes stay isolated",
    "left-before=" ++ left_before ++ ", right-before=" ++ right_before ++ ", left-after=" ++ left_after ++ ", right-after=" ++ right_after ++ ", effect=" ++ has_effect.show,
    left_before == "left" && right_before == "right" && left_after == "left next" && right_after == "" && has_effect)

pub fun listener_registry_guard_test() : <div> test_result
  val handler_slot = named_listener_slot("guard/demo", Click_event, "save")
  val (_unit, duplicate_registry) = run_event_registry(fn() {
    register_listener(handler_slot, Click_registration("save", fn(owner : string) owner))
    register_listener(handler_slot, Click_registration("save", fn(owner : string) owner ++ "!"))
    ()
  })
  val (_unit2, merged_left) = run_event_registry(fn() {
    register_listener(handler_slot, Click_registration("save", fn(owner : string) owner))
    ()
  })
  val (_unit3, merged_right) = run_event_registry(fn() {
    register_listener(handler_slot, Click_registration("danger-remove", fn(owner : string) owner))
    ()
  })
  val merged_registry = append_event_registries(merged_left, merged_right)
  val duplicate_count = count_registered_clicks(duplicate_registry)
  val duplicate_warnings = length(event_registry/warnings(duplicate_registry))
  val merged_warnings = length(event_registry/warnings(merged_registry))
  val merged_semantic = match find_registered_click(merged_registry, state_slot/path(handler_slot))
    Just(found) -> registered_click/semantic_name(found)
    Nothing -> "missing"
  Test_result(
    "Listener registry guards",
    "duplicate-count=" ++ duplicate_count.show ++ ", duplicate-warnings=" ++ duplicate_warnings.show ++ ", merged-warnings=" ++ merged_warnings.show ++ ", semantic=" ++ merged_semantic,
    duplicate_count == 1 && duplicate_warnings == 1 && merged_warnings == 1 && merged_semantic == "danger-remove")
