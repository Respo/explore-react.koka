module demo/todo/view

import demo/model
import demo/shared
import demo/todo/events
import demo/todo/state
import demo/todo/viewmodel
import runtime/dom
import explore/react/core
import explore/react/state

fun task_item_view(item : task, panel_key : string) : app_view vnode
  val tid = task/id(item)
  val draft_marker = feature_dom_marker(group = "todo", key = panel_key, name = "task-draft-" ++ tid.show)
  val (Task_editor_state(editing, draft), dispatch_editor) = use_store(task_editor_store, initial = Task_editor_state(False, item.title))
  val dispatch = fn(action, owner) dispatch_task_item_action(action, item, owner, panel_key = panel_key)
  state_effect(name = "focus-editor", deps = [tid.show, if editing then "editing" else "idle"], action = fn() {
    if editing then {
      dom_focus(draft_marker)
      dom_flash(draft_marker, "effect-pulse")
    } else ()
  })
  val detail = if editing then
      div([
        input_text(draft, key = draft_marker, class = "input", data_effect = draft_marker, input = on_store_input("draft-input", action = Change_draft, dispatch = dispatch_editor), enter = on_action_enter("save-edit", action = Save_task, dispatch = dispatch), placeholder = "Edit title locally before saving..."),
      ], class = "task-main")
    else
      div([
        strong(item.title, class = "task-title"),
        span(if item.done then "done" else "open", class = "task-status"),
      ], class = "task-main")
  val actions = if editing then
      [
        button("Save", class = "button button-primary", click = on_action_click("save-edit", action = Save_task, dispatch = dispatch)),
        button("Cancel", class = "button", click = on_action_click("cancel-edit", action = Cancel_task, dispatch = dispatch)),
      ]
    else
      [
        button("Edit", class = "button", click = on_action_click("start-edit", action = Edit_task, dispatch = dispatch)),
        button(if item.done then "Undo" else "Done", class = "button", click = on_action_click("toggle-task", action = Toggle_task, dispatch = dispatch)),
        button("Remove", class = "button button-danger", click = on_action_click("remove-task", action = Remove_task, dispatch = dispatch)),
      ]
  li([
    detail,
    div(actions, class = "task-actions"),
  ], key = tid.show, class = "task-item")

fun filter_button(label : string, value : string, active : bool, panel_key : string) : app_view vnode
  val class_name = if active then "button button-active" else "button"
  val dispatch = fn(action, owner) dispatch_todo_action(action, owner, panel_key = panel_key)
  button(label, class = class_name, click = on_action_click("set-filter-" ++ value, action = Set_filter(value), dispatch = dispatch))

pub fun todo_panel(panel_state : todo_panel_state, key : string = "panel") : app_view vnode
  feature_root("todo", key) {
    val node_key = feature_node_key(group = "todo", key = key)
    val draft_marker = feature_dom_marker(group = "todo", key = key, name = "draft")
    val note_marker = node_key ++ "-note"
    val dispatch = fn(action, owner) dispatch_todo_action(action, owner, panel_key = key)
    val visible = visible_panel_tasks(panel_state)
    val total = total_task_count(panel_state)
    val should_focus_draft = has_recent_add_notice(panel_state)
    state_effect(name = "focus-draft", deps = [panel_state.notice, panel_state.draft, total.show], action = fn() {
      if should_focus_draft then dom_focus(draft_marker) else ()
    })
    state_effect(name = "pulse-notice", deps = [panel_state.notice, total.show], action = fn() {
      if should_focus_draft then dom_flash(note_marker, "effect-pulse") else ()
    })
    panel([
      div([
        summary_chip("Tasks", total.show),
        summary_chip("Done", done_task_count(panel_state).show),
        summary_chip("Filter", panel_state.filter_name),
      ], class = "summary-row"),
      div([
        input_text(panel_state.draft, class = "input", data_effect = draft_marker, input = on_local_input("draft-input", fn(value, next_owner : model) next_owner(draft = value)), enter = on_action_enter("add-task", action = Add_task, dispatch = dispatch), placeholder = "Add a task or effect experiment..."),
        button("Add", class = "button button-primary", click = on_action_click("add-task", action = Add_task, dispatch = dispatch)),
        button("Clear done", class = "button", click = on_action_click("clear-completed", action = Clear_completed, dispatch = dispatch)),
      ], class = "composer-row"),
      div([
        filter_button("All", value = "all", active = panel_state.filter_name == "all", panel_key = key),
        filter_button("Active", value = "active", active = panel_state.filter_name == "active", panel_key = key),
        filter_button("Done", value = "done", active = panel_state.filter_name == "done", panel_key = key),
      ], class = "button-row"),
      if is-empty(visible) then p("No tasks in this view.", class = "empty") else ul(components(visible, group = "tasks", key = fn(item) task/id(item).show, render = fn(item) task_item_view(item, panel_key = key)), key = "visible-tasks", class = "task-list"),
    ], title = "Todo", note = panel_state.notice, key = node_key, class_name = "todo-panel")
  }
