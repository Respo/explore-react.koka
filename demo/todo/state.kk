module demo/todo/state

import demo/model
import explore/react/core
import explore/react/state

pub struct task_editor_state(editing : bool, draft : string)
pub type task_editor_action
  Begin_edit(title : string)
  Change_draft(value : string)
  Finish_edit
  Cancel_edit(title : string)

fun update_task_editor(current : task_editor_state, action : task_editor_action) : task_editor_state
  match action
    Begin_edit(title) -> Task_editor_state(True, title)
    Change_draft(value) -> Task_editor_state(True, value)
    Finish_edit -> current(editing = False)
    Cancel_edit(title) -> Task_editor_state(False, title)

fun encode_task_editor(current : task_editor_state) : string
  (if current.editing then "1" else "0") ++ current.draft

fun decode_task_editor(version : int, payload : string) : maybe<task_editor_state>
  if version != 1 then Nothing
  else if payload == "" then Nothing
  else if payload.head == "1" then Just(Task_editor_state(True, payload.tail))
  else if payload.head == "0" then Just(Task_editor_state(False, payload.tail))
  else Nothing

fun encode_task_editor_action(action : task_editor_action) : string
  match action
    Begin_edit(title) -> "b" ++ title
    Change_draft(value) -> "d" ++ value
    Finish_edit -> "f"
    Cancel_edit(title) -> "c" ++ title

fun decode_task_editor_action(version : int, payload : string) : maybe<task_editor_action>
  if version != 1 then Nothing
  else if payload == "" then Nothing
  else if payload == "f" then Just(Finish_edit)
  else if payload.head == "b" then Just(Begin_edit(payload.tail))
  else if payload.head == "d" then Just(Change_draft(payload.tail))
  else if payload.head == "c" then Just(Cancel_edit(payload.tail))
  else Nothing

pub val task_editor_store : store_spec<task_editor_state,task_editor_action> = Store_spec(
  "editor",
  State_codec("todo/task-editor", 1, decode_task_editor, encode_task_editor),
  Action_codec("todo/task-editor-action", 1, decode_task_editor_action, encode_task_editor_action),
  update_task_editor)

fun task_component_key(item : task) : string
  task/id(item).show

fun task_scope_path(item : task, panel_key : string) : string
  component_child_path(component_local_path("todo", panel_key), "tasks", task_component_key(item))

pub fun current_task_editor(item : task, panel_key : string = "panel") : <local_state_read,div> task_editor_state
  current_store_state(task_scope_path(item, panel_key), task_editor_store, Task_editor_state(False, item.title))

pub fun dispatch_task_editor(item : task, action : task_editor_action, panel_key : string = "panel") : <local_state_write,div> ()
  dispatch_store(task_scope_path(item, panel_key), task_editor_store, Task_editor_state(False, item.title), action)

pub fun clear_task_editor(item : task, panel_key : string = "panel") : <local_state_write,div> ()
  clear_store_state(task_scope_path(item, panel_key), task_editor_store)

pub fun clear_done_task_editors(tasks : list<task>, panel_key : string = "panel") : <local_state_write,div> ()
  foreach(tasks, fn(item)
    if item.done then clear_task_editor(item, panel_key = panel_key) else ()
  )
