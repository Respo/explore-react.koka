module demo/tests/statecases

import demo/tests/support
import demo/lab/state
import demo/todo/state
import explore/react/action
import explore/react/core
import explore/react/state
import explore/react/runtime
import explore/react/inspection

inline extern reset_effect_test_events() : io ()
  js inline "(globalThis.__respoEffectTestEvents = [])"

inline extern record_effect_test_event(message : string) : io ()
  js inline "globalThis.__respoEffectTestEvents.push(#1)"

inline extern read_effect_test_events() : io string
  js inline "(globalThis.__respoEffectTestEvents || []).join('|')"

inline extern fail_effect_test_cleanup(message : string) : io ()
  js inline "(() => { globalThis.__respoEffectTestEvents.push(#1); throw new Error('expected cleanup failure'); })()"

fun is_effect_install(item : scheduled_effect) : bool
  match scheduled_effect/kind(item)
    Effect_install -> True
    Effect_cleanup -> False

fun is_effect_cleanup(item : scheduled_effect) : bool
  not(is_effect_install(item))

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

pub fun ambient_feature_identity_test() : <div> test_result
  val (resolved, _tree, _effects) = run_local_state(Nil, fn() {
    feature_root(group = "feature", key = "left", render = fn() {
      val root_key = feature_key()
      val child_marker = component("child", "1") { feature_marker("draft") }
      val nested_key = feature_root("feature", "right") { feature_key() }
      val restored_marker = feature_marker("draft")
      [root_key, child_marker, nested_key, restored_marker]
    })
  })
  val passed = resolved == ["feature:left", "feature:left:draft", "feature:right", "feature:left:draft"]
  Test_result(
    "Feature identity stays inside its boundary",
    "resolved=" ++ resolved.show,
    passed)

fun lifecycle_seed_tree() : <div> list<state_entry>
  val (_unit, tree, _effects) = run_local_state(Nil, fn() {
    feature_root("lifecycle", "panel") {
      component("rows", "left") {
        val (_draft, set_draft) = state_pair(name = "draft", initial = "")
        set_draft("left draft")
      }
      component("rows", "right") {
        val (_draft, set_draft) = state_pair(name = "draft", initial = "")
        set_draft("right draft")
      }
    }
  })
  tree

pub fun ordinary_component_lifecycle_test() : <div> test_result
  val root_scope = component_local_path("lifecycle", "panel")
  val left_scope = component_child_path(root_scope, "rows", "left")
  val right_scope = component_child_path(root_scope, "rows", "right")
  val restored_tree = decode_state_snapshot(encode_state_snapshot(lifecycle_seed_tree()))
  val (_unit, next_tree, _effects) = run_local_state(restored_tree, fn() {
    feature_root("lifecycle", "panel") {
      component("rows", "right") {
        state(name = "draft", initial = "")
        ()
      }
    }
  })
  val left_draft = read_named_local_state(next_tree, left_scope, "draft", "<removed>")
  val right_draft = read_named_local_state(next_tree, right_scope, "draft", "<missing>")
  val left_marker_removed = not(any(next_tree, fn(entry) entry.schema == "respo/component-scope" && entry.payload == left_scope))
  val right_marker_kept = any(next_tree, fn(entry) entry.schema == "respo/component-scope" && entry.payload == right_scope)
  Test_result(
    "Ordinary child state is swept after unmount",
    "left=" ++ left_draft ++ ", right=" ++ right_draft ++ ", markers=" ++ left_marker_removed.show ++ "/" ++ right_marker_kept.show,
    left_draft == "<removed>" && right_draft == "right draft" && left_marker_removed && right_marker_kept)

pub fun persistent_feature_lifecycle_test() : <div> test_result
  val root_scope = component_local_path("lifecycle", "panel")
  val left_scope = component_child_path(root_scope, "rows", "left")
  val (_hidden, hidden_tree, _hidden_effects) = run_local_state(lifecycle_seed_tree(), fn() {
    feature_root("other", "panel") { () }
  })
  val restored_tree = decode_state_snapshot(encode_state_snapshot(hidden_tree))
  val (_returned, return_tree, _return_effects) = run_local_state(restored_tree, fn() {
    feature_root("lifecycle", "panel") {
      component("rows", "left") {
        state(name = "draft", initial = "")
        ()
      }
    }
  })
  val restored_draft = read_named_local_state(return_tree, left_scope, "draft", "<missing>")
  Test_result(
    "Unmounted feature root preserves child snapshot",
    "draft=" ++ restored_draft ++ ", hidden-entries=" ++ hidden_tree.length.show,
    restored_draft == "left draft")

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

pub fun replay_empty_payload_test() : <div> test_result
  val scope_name = component_local_path("tests", "empty-replay-payload")
  val empty_codec = Action_codec(
    schema = "tests/empty-action",
    version = 1,
    decode = fn(version, payload) if version == 1 then Just(payload) else Nothing,
    encode = fn(value : string) value)
  val empty_store : store_spec<string,string> = replay_store(
    name = "empty",
    action_codec = empty_codec,
    replay = fn(_action) Replay_start,
    reduce = fn(_current, action) action)
  val (run, _observed) = capture_actions(fn() run_local_state(Nil, fn() feature_root("tests", "empty-replay-payload") {
    val (_current, dispatch) = use_store(empty_store, initial = "fallback")
    dispatch("")
  }))
  val (_unit, tree, _effects) = run
  val restored = read_store_state(
    decode_state_snapshot(encode_state_snapshot(tree)),
    scope_name,
    empty_store,
    "fallback")
  val framed = match find(tree, fn(entry) entry.path == named_local_state_path(scope_name, "empty"))
    Just(entry) -> entry.payload == "a"
    Nothing -> False
  Test_result("Replay framing preserves empty action payload", "restored='" ++ restored ++ "', framed=" ++ framed.show, restored == "" && framed)

pub fun runtime_snapshot_format_test() : <div> test_result
  val source_tree = [
    State_entry("feature/a|b", "tests/state", 3, "draft | value"),
    State_entry("feature/effect", "respo/effect", 1, "render-only"),
  ]
  val encoded = encode_state_snapshot(source_tree)
  val header_is_versioned = match split(encoded, "\n")
    Cons(header, _entries) -> header == "respo/runtime-snapshot|1"
    Nil -> False
  val restored = decode_state_snapshot(encoded)
  val roundtrip = match restored
    [entry] -> entry.path == "feature/a|b" && entry.schema == "tests/state" && entry.version == 3 && entry.payload == "draft | value"
    _ -> False
  val empty_is_versioned = encode_state_snapshot(Nil) == "respo/runtime-snapshot|1"
  val legacy = decode_state_snapshot("legacy/path|legacy/schema|2|legacy%20payload")
  val legacy_compatible = match legacy
    [entry] -> entry.path == "legacy/path" && entry.schema == "legacy/schema" && entry.version == 2 && entry.payload == "legacy payload"
    _ -> False
  val legacy_reencoded = match split(encode_state_snapshot(legacy), "\n")
    Cons(header, _entries) -> header == "respo/runtime-snapshot|1"
    Nil -> False
  val partially_corrupt = decode_state_snapshot(
    "respo/runtime-snapshot|1\nvalid/one|tests/one|1|first\nbad/path|tests/bad|1|bad%\nvalid/two|tests/two|2|second")
  val partial_recovery = match partially_corrupt
    [first, second] -> first.path == "valid/one" && first.payload == "first" && second.path == "valid/two" && second.version == 2
    _ -> False
  val unknown_version_safe = is-empty(decode_state_snapshot("respo/runtime-snapshot|9\nvalid/path|tests/state|1|value"))
  val malformed_version_safe = is-empty(decode_state_snapshot("respo/runtime-snapshot|next\nvalid/path|tests/state|1|value"))
  val malformed_header_safe = is-empty(decode_state_snapshot("respo/runtime-snapshot|1|extra\nvalid/path|tests/state|1|value"))
  Test_result(
    "Runtime snapshot envelope is versioned and backward compatible",
    "header=" ++ header_is_versioned.show ++ ", legacy=" ++ legacy_compatible.show ++ ", partial=" ++ partially_corrupt.length.show ++ ", unknown=" ++ unknown_version_safe.show,
    header_is_versioned && roundtrip && empty_is_versioned && legacy_compatible && legacy_reencoded && partial_recovery && unknown_version_safe && malformed_version_safe && malformed_header_safe)

pub fun effect_dependency_lifecycle_test() : <div> test_result
  val effect_path = named_local_effect_path(component_local_path("effects", "lifecycle"), "resource")
  val (_first, first_tree, first_effects) = run_local_state(Nil, fn() feature_root("effects", "lifecycle") {
    state_resource(name = "resource", deps = ["a"], cleanup = fn() (), action = fn() ())
  })
  val (_same, same_tree, same_effects) = run_local_state(first_tree, fn() feature_root("effects", "lifecycle") {
    state_resource(name = "resource", deps = ["a"], cleanup = fn() (), action = fn() ())
  })
  val (_changed, _changed_tree, changed_effects) = run_local_state(same_tree, fn() feature_root("effects", "lifecycle") {
    state_resource(name = "resource", deps = ["b"], cleanup = fn() (), action = fn() ())
  })
  val first_install = match first_effects
    [item] -> scheduled_effect/path(item) == effect_path && is_effect_install(item)
    _ -> False
  val changed_install = match changed_effects
    [item] -> scheduled_effect/path(item) == effect_path && is_effect_install(item)
    _ -> False
  Test_result(
    "Effect dependencies schedule one managed replacement",
    "first=" ++ first_effects.length.show ++ ", same=" ++ same_effects.length.show ++ ", changed=" ++ changed_effects.length.show,
    first_install && is-empty(same_effects) && changed_install)

pub fun effect_unmount_lifecycle_test() : <div> test_result
  val feature_scope = component_local_path("effects", "unmount")
  val child_scope = component_child_path(feature_scope, "rows", "left")
  val effect_path = named_local_effect_path(child_scope, "resource")
  val (_first, first_tree, _first_effects) = run_local_state(Nil, fn() feature_root("effects", "unmount") {
    component("rows", "left") {
      state_resource(name = "resource", deps = ["mounted"], cleanup = fn() (), action = fn() ())
    }
  })
  val (_unmounted, next_tree, cleanup_effects) = run_local_state(first_tree, fn() feature_root("effects", "unmount") { () })
  val cleanup_once = match cleanup_effects
    [item] -> scheduled_effect/path(item) == effect_path && is_effect_cleanup(item)
    _ -> False
  Test_result(
    "Ordinary component unmount schedules cleanup once",
    "effects=" ++ cleanup_effects.length.show ++ ", entry=" ++ find(next_tree, fn(entry) entry.path == effect_path).is-just.show,
    cleanup_once && find(next_tree, fn(entry) entry.path == effect_path).is-nothing)

pub fun effect_reset_and_persistence_test() : <div> test_result
  val effect_path = named_local_effect_path(component_local_path("effects", "persistent"), "resource")
  val (_first, first_tree, _first_effects) = run_local_state(Nil, fn() feature_root("effects", "persistent") {
    state_resource(name = "resource", deps = ["mounted"], cleanup = fn() (), action = fn() ())
  })
  val (_hidden, hidden_tree, hidden_effects) = run_local_state(first_tree, fn() feature_root("other", "panel") { () })
  val (_reset, reset_tree) = with_component_runtime(hidden_tree, fn() reset_feature(group = "effects", key = "persistent"))
  val reset_effects = reconcile_effect_transitions(hidden_tree, reset_tree, Nil)
  val reset_once = match reset_effects
    [item] -> scheduled_effect/path(item) == effect_path && is_effect_cleanup(item)
    _ -> False
  val hidden_preserved = is-empty(hidden_effects) && find(hidden_tree, fn(entry) entry.path == effect_path).is-just
  Test_result(
    "Persistent effects survive route hiding and clean up on reset",
    "hidden=" ++ hidden_effects.length.show ++ ", reset=" ++ reset_effects.length.show,
    hidden_preserved && reset_once)

pub fun effect_runtime_execution_test() : io test_result
  reset_effect_test_events()
  val report_error = fn(_message) record_effect_test_event("error")
  val first_registry = run_scheduled_effect(
    empty_effect_registry(),
    Scheduled_effect("tests/resource", Effect_install, fn() record_effect_test_event("setup-a"), fn() record_effect_test_event("cleanup-a")),
    report_error)
  val second_registry = run_scheduled_effect(
    first_registry,
    Scheduled_effect("tests/resource", Effect_install, fn() record_effect_test_event("setup-b"), fn() record_effect_test_event("cleanup-b")),
    report_error)
  val empty_registry = run_scheduled_effect(
    second_registry,
    Scheduled_effect("tests/resource", Effect_cleanup, fn() (), fn() ()),
    report_error)
  val failing_registry = run_scheduled_effect(
    empty_registry,
    Scheduled_effect("tests/failing", Effect_install, fn() record_effect_test_event("setup-fail"), fn() fail_effect_test_cleanup("cleanup-fail")),
    report_error)
  val recovered_registry = run_scheduled_effect(
    failing_registry,
    Scheduled_effect("tests/failing", Effect_install, fn() record_effect_test_event("setup-after"), fn() record_effect_test_event("cleanup-after")),
    report_error)
  dispose_effect_registry(recovered_registry, report_error)
  val events = read_effect_test_events()
  val expected = "setup-a|cleanup-a|setup-b|cleanup-b|setup-fail|cleanup-fail|error|setup-after|cleanup-after"
  Test_result(
    "Effect runtime cleans before setup and survives cleanup failure",
    events,
    events == expected)

pub fun action_store_transition_test() : <div> test_result
  val scope_name = component_local_path("tests", "action-store-transition")
  val transition_codec : action_codec<string> = Action_codec(
    schema = "tests/transition-action",
    version = 1,
    decode = fn(version, payload) if version == 1 then Just(payload) else Nothing,
    encode = fn(value : string) value)
  val transition_store : store_spec<string,string> = replay_store(
    name = "transition",
    action_codec = transition_codec,
    replay = fn(_action) Replay_start,
    reduce = fn(_current, action) action)
  val dispatch_domain = fn(action : string, owner : string) {
    emit_action(
      source = "domain",
      target = "tests/transition",
      codec = transition_codec,
      action = action)
    owner ++ action
  }
  val (run, observed) = capture_actions(fn() run_local_state(Nil, fn() feature_root("tests", "action-store-transition") {
    val (_current, dispatch_store) = use_store(transition_store, initial = "idle")
    val complete = action_store_transition(
      "save",
      dispatch = dispatch_domain,
      store_action = "finish",
      store = dispatch_store)
    val rejected = action_store_transition(
      "invalid",
      dispatch = dispatch_domain,
      store_action = "ignored",
      store = dispatch_store,
      store_when = False)
    rejected(complete("owner:"))
  }))
  val (next_owner, tree, _effects) = run
  val next_store = read_store_state(tree, scope_name, transition_store, "idle")
  val ordered = match observed
    [domain_save, component_finish, domain_invalid] ->
      domain_save.source == "domain" && domain_save.payload == "save" &&
      component_finish.source == "component" && component_finish.payload == "finish" &&
      domain_invalid.source == "domain" && domain_invalid.payload == "invalid"
    _ -> False
  Test_result(
    "Domain/store transition preserves typed action order",
    "owner=" ++ next_owner ++ ", store=" ++ next_store ++ ", actions=" ++ observed.length.show,
    next_owner == "owner:saveinvalid" && next_store == "finish" && ordered)

pub fun malformed_store_payload_test() : <div> test_result
  val todo_scope = "tests/malformed-todo"
  val todo_initial = Task_editor_state(False, "todo fallback")
  val todo_tree = [State_entry(named_local_state_path(todo_scope, "editor"), "respo/replay:todo/task-editor-action", 1, "%")]
  val todo_state = read_store_state(todo_tree, todo_scope, task_editor_store, todo_initial)
  val todo_version_tree = [State_entry(named_local_state_path(todo_scope, "editor"), "respo/replay:todo/task-editor-action", 9, "bOld")]
  val todo_version_state = read_store_state(todo_version_tree, todo_scope, task_editor_store, todo_initial)
  val todo_legacy_tree = [State_entry(named_local_state_path(todo_scope, "editor"), "todo/task-editor", 1, "1Old")]
  val todo_legacy_state = read_store_state(todo_legacy_tree, todo_scope, task_editor_store, todo_initial)
  val todo_action_safe = match decode_store_action(task_editor_store, Action_envelope(source = "component", target = todo_scope, schema = "todo/task-editor-action", version = 1, payload = ""))
    Nothing -> True
    _ -> False
  val lab_scope = "tests/malformed-lab"
  val lab_initial = Incident_local_state(False, "lab fallback")
  val lab_tree = [State_entry(named_local_state_path(lab_scope, "incident"), "lab/incident-local", 1, "")]
  val lab_state = read_store_state(lab_tree, lab_scope, incident_local_store, lab_initial)
  val lab_action_safe = match decode_store_action(incident_local_store, Action_envelope(source = "component", target = lab_scope, schema = "lab/incident-local-action", version = 1, payload = ""))
    Nothing -> True
    _ -> False
  val malformed_snapshot_safe = is-empty(decode_state_snapshot("path|schema|1|bad%"))
  val empty_snapshot_payload_valid = length(decode_state_snapshot("path|schema|1|")) == 1
  val passed = todo_state.draft == "todo fallback" && todo_version_state.draft == "todo fallback" && todo_legacy_state.draft == "todo fallback" && lab_state.draft == "lab fallback" && todo_action_safe && lab_action_safe && malformed_snapshot_safe && empty_snapshot_payload_valid
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
      state_effect("record-draft", [draft]) { () }
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
