module demo/lab/state

import explore/react/state

pub struct incident_local_state(expanded : bool, draft : string)
pub type incident_local_action
  Toggle_incident
  Change_incident_draft(value : string)
  Finish_incident_reply

fun update_incident_local_state(current : incident_local_state, action : incident_local_action) : incident_local_state
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

pub val incident_local_store : store_spec<incident_local_state,incident_local_action> = Store_spec(
  "incident",
  State_codec("lab/incident-local", 1, decode_incident_local_state, encode_incident_local_state),
  Action_codec("lab/incident-local-action", 1, decode_incident_local_action, encode_incident_local_action),
  update_incident_local_state)

fun lab_panel_scope_path(panel_key : string = "panel") : string
  component_local_path("lab", panel_key)

fun incident_component_key(incident_id : int) : string
  incident_id.show

fun incident_scope_path(incident_id : int, panel_key : string = "panel") : string
  component_child_path(lab_panel_scope_path(panel_key), "incidents", incident_component_key(incident_id))

pub fun current_incident_local_state(incident_id : int, panel_key : string = "panel") : <local_state_read,div> incident_local_state
  current_store_state(incident_scope_path(incident_id, panel_key), incident_local_store, Incident_local_state(False, ""))

pub fun dispatch_incident_local_action(incident_id : int, action : incident_local_action, panel_key : string = "panel") : <local_state_write,div> ()
  dispatch_store(incident_scope_path(incident_id, panel_key), incident_local_store, Incident_local_state(False, ""), action)
