module demo/tests/todocases

import library/bridge
import demo/model
import demo/runtimeframe
import demo/seed
import demo/tests/support
import demo/todo/events
import demo/todo/state
import explore/react/action
import explore/react/core
import explore/react/renderer
import explore/react/state

pub fun todo_editor_store_protocol_test() : <div> test_result
  val scope_group = "tests"
  val scope_key = "task-editor"
  val scope_name = component_local_path(scope_group, scope_key)
  val initial = Task_editor_state(False, "Initial")
  val (first_run, first_actions) = capture_actions(fn() run_local_state(Nil, fn() feature_root(group = scope_group, key = scope_key, render = fn() {
    val (current, dispatch) = use_store(task_editor_store, initial = initial)
    dispatch(Begin_edit("Draft | with separator"))
    current
  })))
  val (_before, tree, _effects) = first_run
  val current = read_store_state(tree, scope_name, task_editor_store, initial)
  val restored = read_store_state(decode_state_snapshot(encode_state_snapshot(tree)), scope_name, task_editor_store, initial)
  val (sequential_run, _sequential_actions) = capture_actions(fn() run_local_state(Nil, fn() feature_root(group = scope_group, key = scope_key, render = fn() {
    val (_current, dispatch) = use_store(task_editor_store, initial = initial)
    dispatch(Begin_edit("Sequential draft"))
    dispatch(Finish_edit)
    ()
  })))
  val (_sequential_before, sequential_tree, _sequential_effects) = sequential_run
  val sequential = read_store_state(sequential_tree, scope_name, task_editor_store, initial)
  val message = encode_store_action(scope_name, task_editor_store, Change_draft("Next | draft"))
  val action_roundtrip = match decode_store_action(task_editor_store, message)
    Just(Change_draft(value)) -> value == "Next | draft"
    _ -> False
  val version_guard = match decode_store_action(task_editor_store, message(version = 9))
    Nothing -> True
    _ -> False
  val versioned_cell = any(tree, fn(entry) {
    entry.path == named_local_state_path(scope_name, "editor") &&
    entry.schema == "todo/task-editor" &&
    entry.version == 1
  })
  val observed_store_action = match first_actions
    [observed] -> observed.source == "component" && observed.target == scope_name && observed.schema == "todo/task-editor-action" && observed.payload == "bDraft | with separator"
    _ -> False
  Test_result(
    "Todo editor uses typed store protocol",
    "editing=" ++ current.editing.show ++ ", draft=" ++ current.draft ++ ", action=" ++ message.schema ++ "@" ++ message.version.show,
    current.editing && current.draft == "Draft | with separator" && restored.draft == current.draft && not(sequential.editing) && sequential.draft == "Sequential draft" && is-empty(decode_state_snapshot("bad%|schema|1|payload")) && action_roundtrip && version_guard && versioned_cell && observed_store_action)

pub fun unified_action_observation_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val owner = initial_model()
  match find(owner.tasks, fn(item) task/id(item) == 2)
    Nothing -> Test_result("Domain and component actions share one envelope", "task #2 missing", False)
    Just(item) -> {
      val (next_frame, actions) = run_runtime_action_observed(current_runtime_frame(owner, Nil), fn(current_owner) dispatch_task_item_action(Edit_task, item, current_owner))
      val editor = inspect_task_editor(runtime_frame/runtime_tree(next_frame), item)
      val expected_target = component_child_path(component_local_path("todo", "panel"), "tasks", task/id(item).show)
      val valid_actions = match actions
        [domain_action, component_action] -> {
          val domain_decodes = match decode_action(task_item_action_codec, domain_action)
            Just(Edit_task) -> True
            _ -> False
          val component_decodes = match decode_store_action(task_editor_store, component_action)
            Just(Begin_edit(title)) -> title == task/title(item)
            _ -> False
          domain_action.source == "domain" &&
          domain_action.target == "todo/tasks/2" &&
          component_action.source == "component" &&
          component_action.target == expected_target &&
          domain_decodes && component_decodes
        }
        _ -> False
      Test_result(
        "Domain and component actions share one envelope",
        "actions=" ++ length(actions).show ++ ", target=" ++ expected_target ++ ", editing=" ++ editor.editing.show,
        valid_actions && editor.editing)
    }

pub fun todo_edit_local_state_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val base_harness = todo_harness(initial_model())
  val started_harness = todo_harness_click_payload(base_harness, keyed_button_payload(base_harness.tree, "2", "Edit"))
  val started = started_harness.owner
  val drafted_harness = harness_fire_input_channel(started_harness, keyed_input_channel(started_harness.tree, "2", "task-draft-2"), "Prototype local title edits before save", todo_harness_render)
  val drafted = drafted_harness.owner
  val saved_harness = todo_harness_click_payload(drafted_harness, keyed_button_payload(drafted_harness.tree, "2", "Save"))
  val saved = saved_harness.owner
  val title = match find(saved.tasks, fn(item) 2 == task/id(item))
    Just(item) -> item.title
    Nothing -> "missing"
  val started_task = match find(started.tasks, fn(item) 2 == task/id(item))
    Just(item) -> inspect_task_editor(started_harness.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  val saved_task = match find(saved.tasks, fn(item) 2 == task/id(item))
    Just(item) -> inspect_task_editor(saved_harness.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  val local_entries = count_entries(saved_harness.runtime_tree)
  Test_result(
    "Todo item local editing",
    "title=" ++ title ++ ", local=" ++ local_entries.show ++ ", editing=" ++ task_editor_state/editing(started_task).show,
    title == "Prototype local title edits before save" && task_editor_state/editing(started_task) && not(task_editor_state/editing(saved_task)))

pub fun todo_edit_diff_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val base_harness = todo_harness(initial_model())
  val started_harness = todo_harness_click_payload(base_harness, keyed_button_payload(base_harness.tree, "2", "Edit"))
  val drafted_harness = harness_fire_input_channel(started_harness, keyed_input_channel(started_harness.tree, "2", "task-draft-2"), "x", todo_harness_render)
  val patches = diff_node("0", started_harness.tree, drafted_harness.tree)
  val attr_patches = length(filter(patches, fn(item) patch/kind(item) == "set-attr"))
  val replace_patches = length(filter(patches, fn(item) patch/kind(item) == "replace"))
  Test_result(
    "Todo draft uses attribute patch",
    "patches=" ++ length(patches).show ++ ", attrs=" ++ attr_patches.show ++ ", replace=" ++ replace_patches.show,
    attr_patches == 1 && replace_patches == 0)

pub fun add_task_focus_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val seeded = initial_model()(draft = "Queue a fresh task")
  val base_harness = todo_harness(seeded)
  val next_harness = harness_fire_named_click(base_harness, "add-task", todo_harness_render)
  val rendered = next_harness.owner
  val panel_node = next_harness.tree
  val effects = next_harness.effects
  val todo_scope = component_local_path("todo", "panel")
  val focused_draft = any(effects, fn(item) scheduled_effect/path(item) == named_local_effect_path(todo_scope, "focus-draft"))
  val pulsed_notice = any(effects, fn(item) scheduled_effect/path(item) == named_local_effect_path(todo_scope, "pulse-notice"))
  val has_focus_marker = vnode_has_attr_value(panel_node, "data-k-effect", "draft")
  Test_result(
    "Add task schedules focus",
    "draft=" ++ rendered.draft ++ ", effects=" ++ length(effects).show,
    rendered.draft == "" && focused_draft && pulsed_notice && has_focus_marker)

pub fun start_edit_focus_test() : <div> test_result
  with with_test_browser(False, "T+0")
  val base_harness = todo_harness(initial_model())
  val started_harness = todo_harness_click_payload(base_harness, keyed_button_payload(base_harness.tree, "2", "Edit"))
  val rendered = started_harness.owner
  val panel_node = started_harness.tree
  val effects = started_harness.effects
  val expected = match find(rendered.tasks, fn(item) 2 == task/id(item))
    Just(item) -> named_local_effect_path(component_child_path(component_local_path("todo", "panel"), "tasks", task/id(item).show), "focus-editor")
    Nothing -> "missing"
  val expected_marker = match find(rendered.tasks, fn(item) 2 == task/id(item))
    Just(item) -> "task-draft-" ++ task/id(item).show
    Nothing -> "missing"
  val local = match find(rendered.tasks, fn(item) 2 == task/id(item))
    Just(item) -> inspect_task_editor(started_harness.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  val focused_editor = any(effects, fn(item) scheduled_effect/path(item) == expected)
  val has_focus_marker = vnode_has_attr_value(panel_node, "data-k-effect", expected_marker)
  Test_result("Start edit schedules focus", "expected=" ++ expected ++ ", effects=" ++ length(effects).show, task_editor_state/editing(local) && focused_editor && has_focus_marker)
