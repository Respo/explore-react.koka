module demo/todo/view

import demo/model
import demo/shared
import demo/todo/events
import demo/todo/state
import demo/todo/viewmodel
import runtime/dom
import explore/react/core
import explore/react/state

alias todo_view_effect = <hook_scope,local_state_read,todo_local_effect,listener_registry<model,browser_event_effect>>

fun status_text(done : bool) : string
  if done then "done" else "open"

pub fun task_item_view(item : task) : todo_view_effect vnode
  {
    val tid = task/id(item)
    val editor = use_store(task_editor_store, initial = Task_editor_state(False, item.title))
    val editing = editor.current.editing
    val draft = editor.current.draft
    val start_edit = on_local_click("start-edit", fn(owner : model) commit_task_tree(owner, fn() {
      audit("Opened local edit state for task #" ++ tid.show)
      editor.send.(Begin_edit(item.title))
      owner(notice = "Editing task locally before committing the title.")
    }))
    val save_edit = on_local_click("save-edit", fn(owner : model) commit_task_tree(owner, fn() {
      if draft == "" then
        owner(notice = "Task title cannot be empty.")
      else {
        audit("Saved local task edit for #" ++ tid.show)
        editor.send.(Finish_edit)
        owner(
          tasks = map(owner.tasks, fn(task_item) if task/id(task_item) == tid then task_item(title = draft) else task_item),
          notice = "Saved task title from local state.")
      }
    }))
    val cancel_edit = on_local_click("cancel-edit", fn(owner : model) commit_task_tree(owner, fn() {
      editor.send.(Cancel_edit(item.title))
      owner(notice = "Cancelled local task edit.")
    }))
    val toggle_task = on_local_click("toggle-task", fn(owner : model) {
      audit("Toggled task state from the Koka reducer.")
      owner(
        tasks = map(owner.tasks, fn(task_item) if task/id(task_item) == tid then task_item(done = not(task_item.done)) else task_item),
        notice = "Toggled a task.")
    })
    val remove_task = on_local_click("remove-task", fn(owner : model) {
      if confirm_action("Remove `" ++ item.title ++ "`?") then
        commit_task_tree(owner, fn() {
          audit("Removed task after confirmation: " ++ item.title)
          clear_task_editor(item)
          owner(
            tasks = filter(owner.tasks, fn(task_item) task/id(task_item) != tid),
            notice = "Task removed after confirm effect.")
        })
      else
        owner(notice = "Removal cancelled by confirm effect.")
    })
    val save_edit_enter = on_local_enter("save-edit", fn(owner : model) commit_task_tree(owner, fn() {
      if draft == "" then
        owner(notice = "Task title cannot be empty.")
      else {
        audit("Saved local task edit for #" ++ tid.show)
        editor.send.(Finish_edit)
        owner(
          tasks = map(owner.tasks, fn(task_item) if task/id(task_item) == tid then task_item(title = draft) else task_item),
          notice = "Saved task title from local state.")
      }
    }))
    state_effect(name = "focus-editor", deps = [tid.show, if editing then "editing" else "idle"], action = fn() {
      if editing then {
        dom_focus("task-draft-" ++ tid.show)
        dom_flash("task-draft-" ++ tid.show, "effect-pulse")
      } else ()
    })
    val detail = if editing then
        div([
          input_text(draft, key = "task-draft-" ++ tid.show, class = "input", data_effect = "task-draft-" ++ tid.show, input = on_local_input("draft-input", fn(value, owner) commit_task_tree(owner, fn() {
                editor.send.(Change_draft(value))
                owner
              })), enter = save_edit_enter, placeholder = "Edit title locally before saving..."),
        ], class = "task-main")
      else
        div([
          strong(item.title, class = "task-title"),
          span(status_text(item.done), class = "task-status"),
        ], class = "task-main")
    val actions = if editing then
        [
          button("Save", class = "button button-primary", click = save_edit),
          button("Cancel", class = "button", click = cancel_edit),
        ]
      else
        [
          button("Edit", class = "button", click = start_edit),
          button(if item.done then "Undo" else "Done", class = "button", click = toggle_task),
          button("Remove", class = "button button-danger", click = remove_task),
        ]
    li([
      detail,
      div(actions, class = "task-actions"),
    ], key = tid.show, class = "task-item")
  }

fun render_task_items_view(tasks : list<task>) : todo_view_effect list<vnode>
  map(tasks, fn(item) component_in("tasks", task/id(item).show, fn() task_item_view(item)))

fun task_list(key : string, tasks : list<task>) : todo_view_effect vnode
  if is-empty(tasks) then p("No tasks in this view.", class = "empty") else ul(render_task_items_view(tasks), key = key, class = "task-list")

fun filter_button(label : string, value : string, active : bool) : <hook_scope,listener_registry<model,browser_event_effect>,div> vnode
  val class_name = if active then "button button-active" else "button"
  button(label, class = class_name, click = on_local_click("set-filter-" ++ value, fn(m : model) dispatch_todo_action(Set_filter(value), m)))

pub fun render_todo_panel(owner : model, panel_state : todo_panel_state) : todo_view_effect vnode
  {
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
        input_text(panel_state.draft, class = "input", data_effect = "draft", input = on_local_input("draft-input", fn(value, next_owner : model) next_owner(draft = value)), enter = on_local_enter("add-task", fn(m : model) dispatch_todo_action(Add_task, m)), placeholder = "Add a task or effect experiment..."),
        button("Add", class = "button button-primary", click = on_local_click("add-task", fn(m : model) dispatch_todo_action(Add_task, m))),
        button("Clear done", class = "button", click = on_local_click("clear-completed", fn(m : model) dispatch_todo_action(Clear_completed, m))),
      ], class = "composer-row"),
      div([
        filter_button("All", "all", panel_state.filter_name == "all"),
        filter_button("Active", "active", panel_state.filter_name == "active"),
        filter_button("Done", "done", panel_state.filter_name == "done"),
      ], class = "button-row"),
      task_list("visible-tasks", visible),
    ], title = "Todo", note = panel_state.notice, key = "todo", class_name = "todo-panel")
  }
