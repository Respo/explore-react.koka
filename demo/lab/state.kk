module demo/lab/state

import demo/model
import demo/runtimeowner
import explore/react/state

pub struct incident_local_state(expanded : bool, draft : string)
pub alias lab_local_effect = <local_state_write,hook_state,hook_effects,div>

pub fun lab_panel_scope_path() : string
  component_local_path("lab", "panel")

fun incident_component_key(incident_id : int) : string
  incident_id.show

fun incident_scope_path(incident_id : int) : string
  child_scope(lab_panel_scope_path(), "incidents", incident_component_key(incident_id))

pub fun lab_incident_expanded(tree : list<state_entry>, incident_id : int) : <div> bool
  state_value(tree, hook_state_slot(incident_scope_path(incident_id), 0), flag_state_codec, False)

pub fun lab_incident_draft(tree : list<state_entry>, incident_id : int) : <div> string
  state_value(tree, hook_state_slot(incident_scope_path(incident_id), 1), text_state_codec, "")

pub fun finalize_incident_reply_tree(tree : list<state_entry>, incident_id : int) : <div> list<state_entry>
  clear_slot_state(
    assoc_slot_value(tree, hook_state_slot(incident_scope_path(incident_id), 0), flag_state_codec, True),
    hook_state_slot(incident_scope_path(incident_id), 1))

pub fun commit_lab_tree(owner : model, action : () -> <lab_local_effect,local_state_read,hook_scope|e> model) : <div|e> model
  runtimeowner/run_attached_local_state(owner, action)

pub fun set_local_lab_draft(owner : model, incident_id : int, draft : string) : <lab_local_effect> model
  if draft == "" then
    clear_local_state(state_slot/path(hook_state_slot(incident_scope_path(incident_id), 1)))
  else
    set_named_state(hook_state_slot(incident_scope_path(incident_id), 1), text_state_codec, draft)
  owner

pub fun toggle_local_lab_expanded(owner : model, incident_id : int) : <lab_local_effect> model
  set_named_state(hook_state_slot(incident_scope_path(incident_id), 0), flag_state_codec, not(lab_incident_expanded(runtimeowner/attached_runtime_tree(owner), incident_id)))
  owner