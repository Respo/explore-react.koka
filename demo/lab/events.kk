module demo/lab/events

import demo/lab/search
import demo/model
import demo/lab/state
import demo/lab/workflow
import library/bridge
import library/maybe
import library/search
import explore/react/state

pub type lab_action
  Load_board
  Run_sync
  Load_bridge_case(case_name : string)
  Change_search_query(value : string)
  Submit_search
  Search_for(query : string)
  Send_reply(incident_id : int)

fun find_lab_draft_channel(channel : string, items : list<incident>) : <div> maybe<int>
  find(items, fn(item) channel == "lab-draft-" ++ incident/id(item).show).map(incident/id)

fun incident_id_from_toggle(payload : string, items : list<incident>) : <div> maybe<int>
  find(items, fn(item) payload == "lab-toggle-" ++ incident/id(item).show).map(incident/id)

fun incident_id_from_send(payload : string, items : list<incident>) : <div> maybe<int>
  find(items, fn(item) payload == "lab-send-" ++ incident/id(item).show).map(incident/id)

pub fun dispatch_lab_action(action : lab_action, owner : model) : <lab_action_effect,local_state_read,local_state_write,div> model
  match action
    Load_board -> load_snapshot(owner)
    Run_sync -> perform_sync(owner)
    Load_bridge_case(case_name) -> start_bridge_case(owner, case_name)
    Change_search_query(value) -> set_search_query(owner, value)
    Submit_search -> start_search(owner)
    Search_for(query) -> pick_search_case(owner, query)
    Send_reply(incident_id) -> send_reply(owner, incident_id)

fun decode_lab_action(payload : string, owner : model) : <div> maybe<lab_action>
  if payload == "lab-load" then
    Just(Load_board)
  else if payload == "lab-sync" then
    Just(Run_sync)
  else if payload == search_submit_payload() then
    Just(Submit_search)
  else
    decode_bridge_load_payload(payload).map(Load_bridge_case) ||
    decode_search_pick_payload(payload).map(Search_for) ||
    incident_id_from_send(payload, owner.lab.incidents).map(Send_reply)

pub fun route_lab_click(payload : string, owner : model) : <lab_action_effect,local_state_read,local_state_write,div> maybe<model>
  decode_lab_action(payload, owner).map(fn(action) dispatch_lab_action(action, owner)).or-else {
    resolve_search_result(owner, payload).or-else {
      resolve_bridge_result(owner, payload).or-else {
        incident_id_from_toggle(payload, owner.lab.incidents).map(fn(target_id) {
          dispatch_incident_local_action(target_id, Toggle_incident)
          owner
        })
      }
    }
  }

pub fun route_lab_input(channel : string, value : string, owner : model) : <bridge_request_effect,local_state_write,div> maybe<model>
  if channel == search_query_channel() then
    Just(set_search_query(owner, value))
  else
    find_lab_draft_channel(channel, owner.lab.incidents).map(fn(target_id) {
      dispatch_incident_local_action(target_id, Change_incident_draft(value))
      owner
    })
