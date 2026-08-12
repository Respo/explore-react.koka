module demo/todo/state

import demo/model
import demo/runtimeowner
import explore/react/core
import explore/react/state

pub struct task_editor_state(editing : bool, draft : string)
pub alias todo_local_effect = <local_state_write,hook_state,hook_effects,div>

pub fun todo_panel_scope_path() : string
  component_local_path("todo", "panel")

fun task_component_key(item : task) : string
  task/id(item).show

fun task_scope_path(item : task) : string
  child_scope(todo_panel_scope_path(), "tasks", task_component_key(item))

pub fun todo_panel_listener_path(kind : dom_event_kind, name : string) : string
  state_slot/path(named_listener_slot(todo_panel_scope_path(), kind, name))

pub fun todo_panel_effect_path(index : int) : string
  state_slot/path(hook_effect_slot(todo_panel_scope_path(), index))

pub fun task_listener_path(item : task, kind : dom_event_kind, name : string) : string
  state_slot/path(named_listener_slot(task_scope_path(item), kind, name))

pub fun task_effect_path(item : task, index : int) : string
  state_slot/path(hook_effect_slot(task_scope_path(item), index))

fun read_task_state(tree : list<state_entry>, item : task) : <div> task_editor_state
  Task_editor_state(
    state_value(tree, hook_state_slot(task_scope_path(item), 0), flag_state_codec, False),
    state_value(tree, hook_state_slot(task_scope_path(item), 1), text_state_codec, item.title))

pub fun clear_task_editor(item : task) : <local_state_write,div> ()
  clear_local_state(task_scope_path(item))

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