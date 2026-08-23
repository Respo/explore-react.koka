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
  component_child_path(lab_panel_scope_path(), "incidents", incident_component_key(incident_id))

pub fun lab_incident_expanded(tree : list<state_entry>, incident_id : int) : <div> bool
  read_named_local_state(tree, incident_scope_path(incident_id), "expanded", False)

pub fun lab_incident_draft(tree : list<state_entry>, incident_id : int) : <div> string
  read_named_local_state(tree, incident_scope_path(incident_id), "draft", "")

pub fun finalize_incident_reply_tree(tree : list<state_entry>, incident_id : int) : <div> list<state_entry>
  clear_named_local_state_in_tree(
    assoc_named_local_state(tree, incident_scope_path(incident_id), "expanded", True),
    incident_scope_path(incident_id),
    "draft")

pub fun commit_lab_tree(owner : model, action : () -> <lab_local_effect,local_state_read,hook_scope|e> model) : <div|e> model
  runtimeowner/run_attached_local_state(owner, action)

pub fun set_local_lab_draft(owner : model, incident_id : int, draft : string) : <lab_local_effect> model
  if draft == "" then
    clear_named_local_state(incident_scope_path(incident_id), "draft")
  else
    set_named_local_state(incident_scope_path(incident_id), "draft", draft)
  owner

pub fun toggle_local_lab_expanded(owner : model, incident_id : int) : <lab_local_effect> model
  set_named_local_state(incident_scope_path(incident_id), "expanded", not(lab_incident_expanded(runtimeowner/attached_runtime_tree(owner), incident_id)))
  owner
