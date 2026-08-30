module demo/todo/state

import explore/react/action
import explore/react/state

pub struct task_editor_state(editing : bool, draft : string)
pub type task_editor_action
  Begin_edit(title : string)
  Change_draft(value : string)
  Finish_edit
  Cancel_edit(title : string)

fun reduce_task_editor(current : task_editor_state, action : task_editor_action) : task_editor_state
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
  name = "editor",
  state_codec = State_codec(
    schema = "todo/task-editor",
    version = 1,
    decode = decode_task_editor,
    encode = encode_task_editor),
  action_codec = Action_codec(
    schema = "todo/task-editor-action",
    version = 1,
    decode = decode_task_editor_action,
    encode = encode_task_editor_action),
  reduce = reduce_task_editor)
