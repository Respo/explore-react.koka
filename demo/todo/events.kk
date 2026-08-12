module demo/todo/events

import demo/model
import demo/todo/state
import library/maybe
import explore/react/core
import explore/react/state

pub type todo_action
  Add_task
  Set_filter(filter_name : string)
  Clear_completed

fun append_tasks(tasks : list<task>, item : task) : <div> list<task>
  tasks ++ [item]

fun clear_completed_tasks(tasks : list<task>) : <div> list<task>
  filter(tasks, fn(item) not(item.done))

fun clear_done_local_state(tasks : list<task>) : <local_state_write,div> ()
  clear_done_task_editors(tasks)

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

fun todo_handle_clear_completed(owner : model) : <browser_host,local_state_write,div> model
  if not(any(owner.tasks, fn(item) item.done)) then
    owner(notice = "There are no completed tasks to clear.")
  else if confirm_action("Clear every completed task?") then {
    audit("Cleared completed tasks.")
    clear_done_local_state(owner.tasks)
    val next = owner(tasks = clear_completed_tasks(owner.tasks))
    next(notice = "Completed tasks cleared after confirm effect.")
  } else
    owner(notice = "Clear completed cancelled.")

pub fun dispatch_todo_action(action : todo_action, owner : model) : <browser_host,div> model
  match action
    Add_task -> commit_task_hooks(owner, fn() todo_add_task(owner))
    Set_filter(filter_name) -> owner(filter_name = filter_name, notice = "Primary list switched to `" ++ filter_name ++ "`.")
    Clear_completed -> commit_task_hooks(owner, fn() todo_handle_clear_completed(owner))
