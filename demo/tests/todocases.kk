module demo/tests/todocases

import library/bridge
import demo/model
import demo/seed
import demo/tests/support
import demo/todo/state
import demo/todopanel
import explore/react/core
import explore/react/renderer
import explore/react/state

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
    Just(item) -> snapshot_task_editor(started_harness.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  val saved_task = match find(saved.tasks, fn(item) 2 == task/id(item))
    Just(item) -> snapshot_task_editor(saved_harness.runtime_tree, item)
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
  val focused_draft = any(effects, fn(item) scheduled_effect/path(item) == todo_panel_effect_path(0))
  val pulsed_notice = any(effects, fn(item) scheduled_effect/path(item) == todo_panel_effect_path(1))
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
    Just(item) -> task_effect_path(item, 0)
    Nothing -> "missing"
  val expected_marker = match find(rendered.tasks, fn(item) 2 == task/id(item))
    Just(item) -> "task-draft-" ++ task/id(item).show
    Nothing -> "missing"
  val local = match find(rendered.tasks, fn(item) 2 == task/id(item))
    Just(item) -> snapshot_task_editor(started_harness.runtime_tree, item)
    Nothing -> Task_editor_state(False, "")
  val focused_editor = any(effects, fn(item) scheduled_effect/path(item) == expected)
  val has_focus_marker = vnode_has_attr_value(panel_node, "data-k-effect", expected_marker)
  Test_result("Start edit schedules focus", "expected=" ++ expected ++ ", effects=" ++ length(effects).show, task_editor_state/editing(local) && focused_editor && has_focus_marker)