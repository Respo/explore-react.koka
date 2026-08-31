module demo/lab/state

import explore/react

pub struct incident_local_state(expanded : bool, draft : string)
pub type incident_local_action
  Toggle_incident
  Change_incident_draft(value : string)
  Finish_incident_reply

fun reduce_incident_local_state(current : incident_local_state, action : incident_local_action) : incident_local_state
  match action
    Toggle_incident -> current(expanded = not(current.expanded))
    Change_incident_draft(value) -> current(draft = value)
    Finish_incident_reply -> current(expanded = True, draft = "")

fun encode_incident_local_state(current : incident_local_state) : string
  (if current.expanded then "1" else "0") ++ current.draft

fun decode_incident_local_state(version : int, payload : string) : maybe<incident_local_state>
  if version != 1 then Nothing
  else if payload == "" then Nothing
  else if payload.head == "1" then Just(Incident_local_state(True, payload.tail))
  else if payload.head == "0" then Just(Incident_local_state(False, payload.tail))
  else Nothing

fun encode_incident_local_action(action : incident_local_action) : string
  match action
    Toggle_incident -> "t"
    Change_incident_draft(value) -> "d" ++ value
    Finish_incident_reply -> "f"

fun decode_incident_local_action(version : int, payload : string) : maybe<incident_local_action>
  if version != 1 then Nothing
  else if payload == "" then Nothing
  else if payload == "t" then Just(Toggle_incident)
  else if payload == "f" then Just(Finish_incident_reply)
  else if payload.head == "d" then Just(Change_incident_draft(payload.tail))
  else Nothing

pub val incident_local_store : store_spec<incident_local_state,incident_local_action> = snapshot_store(
  name = "incident",
  state_codec = State_codec(
    schema = "lab/incident-local",
    version = 1,
    decode = decode_incident_local_state,
    encode = encode_incident_local_state),
  action_codec = Action_codec(
    schema = "lab/incident-local-action",
    version = 1,
    decode = decode_incident_local_action,
    encode = encode_incident_local_action),
  reduce = reduce_incident_local_state)
