module demo/todo/state

import demo/model
import demo/runtimeowner
import explore/react/core
import explore/react/state

pub struct task_editor_state(editing : bool, draft : string)
pub type task_editor_action
  Begin_edit(title : string)
  Change_draft(value : string)
  Finish_edit
  Cancel_edit(title : string)

pub alias todo_local_effect = <local_state_write,hook_state,hook_effects,div>

pub fun update_task_editor(current : task_editor_state, action : task_editor_action) : task_editor_state
  match action
    Begin_edit(title) -> Task_editor_state(True, title)
    Change_draft(value) -> Task_editor_state(True, value)
    Finish_edit -> current(editing = False)
    Cancel_edit(title) -> Task_editor_state(False, title)

fun encode_task_editor(current : task_editor_state) : string
  (if current.editing then "1" else "0") ++ current.draft

fun decode_task_editor(version : int, payload : string) : maybe<task_editor_state>
  if version != 1 then Nothing
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
  else if payload.head == "b" then Just(Begin_edit(payload.tail))
  else if payload.head == "d" then Just(Change_draft(payload.tail))
  else if payload.head == "c" then Just(Cancel_edit(payload.tail))
  else if payload == "f" then Just(Finish_edit)
  else Nothing

pub val task_editor_store : store_spec<task_editor_state,task_editor_action> = Store_spec(
  "editor",
  State_codec("todo/task-editor", 1, decode_task_editor, encode_task_editor),
  Action_codec("todo/task-editor-action", 1, decode_task_editor_action, encode_task_editor_action),
  update_task_editor)

pub fun todo_panel_scope_path() : string
  component_local_path("todo", "panel")

fun task_component_key(item : task) : string
  task/id(item).show

fun task_scope_path(item : task) : string
  component_child_path(todo_panel_scope_path(), "tasks", task_component_key(item))

pub fun todo_panel_listener_path(kind : dom_event_kind, name : string) : string
  named_local_listener_path(todo_panel_scope_path(), kind, name)

pub fun todo_panel_effect_path(effect_name : string) : string
  named_local_effect_path(todo_panel_scope_path(), effect_name)

pub fun task_listener_path(item : task, kind : dom_event_kind, name : string) : string
  named_local_listener_path(task_scope_path(item), kind, name)

pub fun task_effect_path(item : task, effect_name : string) : string
  named_local_effect_path(task_scope_path(item), effect_name)

fun read_task_state(tree : list<state_entry>, item : task) : <div> task_editor_state
  read_store_state(tree, task_scope_path(item), task_editor_store, Task_editor_state(False, item.title))

pub fun clear_task_editor(item : task) : <local_state_write,div> ()
  clear_store_state(task_scope_path(item), task_editor_store)

pub fun clear_done_task_editors(tasks : list<task>) : <local_state_write,div> ()
  foreach(tasks, fn(item)
    if item.done then clear_task_editor(item) else ()
  )

pub fun commit_task_hooks(owner : model, action : () -> <todo_local_effect,local_state_read,hook_scope|e> model) : <div|e> model
  runtimeowner/run_attached_local_state(owner, action)

pub fun commit_task_tree(owner : model, action : () -> <todo_local_effect,local_state_read,hook_scope|e> model) : <div|e> model
  commit_task_hooks(owner, action)

pub fun snapshot_task_editor(tree : list<state_entry>, item : task) : <div> task_editor_state
  read_task_state(tree, item)
