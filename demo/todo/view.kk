module demo/todo/view

import demo/model
import demo/shared
import demo/todo/events
import demo/todo/state
import demo/todo/viewmodel
import runtime/dom
import explore/react/core
import explore/react/state

alias todo_view_effect = <hook_scope,local_state_read,hook_effects,listener_registry<model,browser_event_effect>,div>

fun task_item_view(item : task) : todo_view_effect vnode
  val tid = task/id(item)
  val editor = use_store(task_editor_store, initial = Task_editor_state(False, item.title))
  val Task_editor_state(editing, draft) = editor.current
  val dispatch = fn(action, owner) dispatch_task_item_action(action, item, owner)
  state_effect(name = "focus-editor", deps = [tid.show, if editing then "editing" else "idle"], action = fn() {
    if editing then {
      dom_focus("task-draft-" ++ tid.show)
      dom_flash("task-draft-" ++ tid.show, "effect-pulse")
    } else ()
  })
  val detail = if editing then
      div([
        input_text(draft, key = "task-draft-" ++ tid.show, class = "input", data_effect = "task-draft-" ++ tid.show, input = on_store_input("draft-input", editor, Change_draft), enter = on_action_enter("save-edit", action = Save_task, dispatch = dispatch), placeholder = "Edit title locally before saving..."),
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

fun filter_button(label : string, value : string, active : bool) : <hook_scope,listener_registry<model,browser_event_effect>,div> vnode
  val class_name = if active then "button button-active" else "button"
  button(label, class = class_name, click = on_action_click("set-filter-" ++ value, action = Set_filter(value), dispatch = dispatch_todo_action))

pub fun render_todo_panel(panel_state : todo_panel_state) : todo_view_effect vnode
  val visible = visible_panel_tasks(panel_state)
  val total = total_task_count(panel_state)
  val should_focus_draft = has_recent_add_notice(panel_state)
  state_effect(name = "focus-draft", deps = [panel_state.notice, panel_state.draft, total.show], action = fn() {
    if should_focus_draft then dom_focus("draft") else ()
  })
  state_effect(name = "pulse-notice", deps = [panel_state.notice, total.show], action = fn() {
    if should_focus_draft then dom_flash("todo-note", "effect-pulse") else ()
  })
  panel([
    div([
      summary_chip("Tasks", total.show),
      summary_chip("Done", done_task_count(panel_state).show),
      summary_chip("Filter", panel_state.filter_name),
    ], class = "summary-row"),
    div([
      input_text(panel_state.draft, class = "input", data_effect = "draft", input = on_local_input("draft-input", fn(value, next_owner : model) next_owner(draft = value)), enter = on_action_enter("add-task", action = Add_task, dispatch = dispatch_todo_action), placeholder = "Add a task or effect experiment..."),
      button("Add", class = "button button-primary", click = on_action_click("add-task", action = Add_task, dispatch = dispatch_todo_action)),
      button("Clear done", class = "button", click = on_action_click("clear-completed", action = Clear_completed, dispatch = dispatch_todo_action)),
    ], class = "composer-row"),
    div([
      filter_button("All", "all", panel_state.filter_name == "all"),
      filter_button("Active", "active", panel_state.filter_name == "active"),
      filter_button("Done", "done", panel_state.filter_name == "done"),
    ], class = "button-row"),
    if is-empty(visible) then p("No tasks in this view.", class = "empty") else ul(components(visible, group = "tasks", key = fn(item) task/id(item).show, render = task_item_view), key = "visible-tasks", class = "task-list"),
  ], title = "Todo", note = panel_state.notice, key = "todo", class_name = "todo-panel")
