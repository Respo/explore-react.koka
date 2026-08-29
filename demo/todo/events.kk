module demo/todo/events

import demo/model
import demo/todo/state
import library/maybe
import explore/react/action
import explore/react/core
import explore/react/state

pub type todo_action
  Add_task
  Set_filter(filter_name : string)
  Clear_completed

pub type task_item_action
  Edit_task
  Save_task
  Cancel_task
  Toggle_task
  Remove_task

fun encode_todo_action(action : todo_action) : string
  match action
    Add_task -> "a"
    Set_filter(filter_name) -> "f" ++ filter_name
    Clear_completed -> "c"

fun decode_todo_action(version : int, payload : string) : maybe<todo_action>
  if version != 1 then Nothing
  else if payload == "a" then Just(Add_task)
  else if payload == "c" then Just(Clear_completed)
  else if payload != "" && payload.head == "f" then Just(Set_filter(payload.tail))
  else Nothing

pub val todo_action_codec : action_codec<todo_action> = Action_codec(
  schema = "todo/action",
  version = 1,
  decode = decode_todo_action,
  encode = encode_todo_action)

fun encode_task_item_action(action : task_item_action) : string
  match action
    Edit_task -> "e"
    Save_task -> "s"
    Cancel_task -> "c"
    Toggle_task -> "t"
    Remove_task -> "r"

fun decode_task_item_action(version : int, payload : string) : maybe<task_item_action>
  if version != 1 then Nothing
  else if payload == "e" then Just(Edit_task)
  else if payload == "s" then Just(Save_task)
  else if payload == "c" then Just(Cancel_task)
  else if payload == "t" then Just(Toggle_task)
  else if payload == "r" then Just(Remove_task)
  else Nothing

pub val task_item_action_codec : action_codec<task_item_action> = Action_codec(
  schema = "todo/task-action",
  version = 1,
  decode = decode_task_item_action,
  encode = encode_task_item_action)

fun append_tasks(tasks : list<task>, item : task) : <div> list<task>
  tasks ++ [item]

fun clear_completed_tasks(tasks : list<task>) : <div> list<task>
  filter(tasks, fn(item) not(item.done))

fun clear_done_local_state(tasks : list<task>, panel_key : string) : <local_state_write,div> ()
  clear_done_task_editors(tasks, panel_key = panel_key)

fun todo_add_task(owner : model) : <browser_host,div> model
  if owner.draft == "" then
    owner(notice = "Draft is empty. Type something before adding.")
  else {
    audit("Added task: " ++ owner.draft)
    val next_task = Task(owner.next_id, owner.draft, False)
    val with_task = owner(tasks = append_tasks(owner.tasks, next_task))
    val with_draft = with_task(draft = "")
    val with_next_id = with_draft(next_id = owner.next_id + 1)
    with_next_id(notice = "Added a new task from the Koka store.")
  }

fun todo_handle_clear_completed(owner : model, panel_key : string) : <browser_host,local_state_write,div> model
  if not(any(owner.tasks, fn(item) item.done)) then
    owner(notice = "There are no completed tasks to clear.")
  else if confirm_action("Clear every completed task?") then {
    audit("Cleared completed tasks.")
    clear_done_local_state(owner.tasks, panel_key = panel_key)
    val next = owner(tasks = clear_completed_tasks(owner.tasks))
    next(notice = "Completed tasks cleared after confirm effect.")
  } else
    owner(notice = "Clear completed cancelled.")

pub fun dispatch_todo_action(action : todo_action, owner : model, panel_key : string = "panel") : <browser_event_effect,div> model
  emit_action(source = "domain", target = "todo", codec = todo_action_codec, action = action)
  match action
    Add_task -> todo_add_task(owner)
    Set_filter(filter_name) -> owner(filter_name = filter_name, notice = "Primary list switched to `" ++ filter_name ++ "`.")
    Clear_completed -> todo_handle_clear_completed(owner, panel_key = panel_key)

pub fun dispatch_task_item_action(
  action : task_item_action,
  item : task,
  owner : model,
  panel_key : string = "panel"
) : <browser_event_effect,div> model
  val tid = task/id(item)
  emit_action(source = "domain", target = "todo/tasks/" ++ tid.show, codec = task_item_action_codec, action = action)
  match action
    Edit_task -> {
      audit("Opened local edit state for task #" ++ tid.show)
      dispatch_task_editor(item, Begin_edit(item.title), panel_key = panel_key)
      owner(notice = "Editing task locally before committing the title.")
    }
    Save_task -> {
      val draft = current_task_editor(item, panel_key = panel_key).draft
      if draft == "" then
        owner(notice = "Task title cannot be empty.")
      else {
        audit("Saved local task edit for #" ++ tid.show)
        dispatch_task_editor(item, Finish_edit, panel_key = panel_key)
        owner(
          tasks = map(owner.tasks, fn(task_item) if task/id(task_item) == tid then task_item(title = draft) else task_item),
          notice = "Saved task title from local state.")
      }
    }
    Cancel_task -> {
      dispatch_task_editor(item, Cancel_edit(item.title), panel_key = panel_key)
      owner(notice = "Cancelled local task edit.")
    }
    Toggle_task -> {
      audit("Toggled task state from the Koka reducer.")
      owner(
        tasks = map(owner.tasks, fn(task_item) if task/id(task_item) == tid then task_item(done = not(task_item.done)) else task_item),
        notice = "Toggled a task.")
    }
    Remove_task -> {
      if confirm_action("Remove `" ++ item.title ++ "`?") then {
        audit("Removed task after confirmation: " ++ item.title)
        clear_task_editor(item, panel_key = panel_key)
        owner(
          tasks = filter(owner.tasks, fn(task_item) task/id(task_item) != tid),
          notice = "Task removed after confirm effect.")
      }
      else
        owner(notice = "Removal cancelled by confirm effect.")
    }
