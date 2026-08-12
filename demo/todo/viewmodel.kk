module demo/todo/viewmodel

import demo/model

pub struct todo_panel_state
  tasks : list<task>
  draft : string
  filter_name : string
  notice : string

pub fun todo_panel_state_of(owner : model) : todo_panel_state
  Todo_panel_state(owner.tasks, owner.draft, owner.filter_name, owner.notice)

fun task_visible(filter_name : string, item : task) : bool
  if filter_name == "active" then not(item.done)
  else if filter_name == "done" then item.done
  else True

pub fun visible_panel_tasks(item : todo_panel_state) : <div> list<task>
  filter(item.tasks, fn(task_item) task_visible(item.filter_name, task_item))

pub fun total_task_count(item : todo_panel_state) : <div> int
  length(item.tasks)

pub fun done_task_count(item : todo_panel_state) : <div> int
  length(filter(item.tasks, fn(task_item) task_item.done))

pub fun has_recent_add_notice(item : todo_panel_state) : bool
  item.notice == "Added a new task from the Koka store."