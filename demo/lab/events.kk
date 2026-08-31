module demo/lab/events

import demo/lab/search
import demo/model
import demo/lab/workflow
import library/bridge
import library/maybe
import library/search
import explore/react

pub type lab_action
  Load_board
  Run_sync
  Load_bridge_case(case_name : string)
  Change_search_query(value : string)
  Submit_search
  Search_for(query : string)
  Send_reply(incident_id : int, message : string)

fun encode_lab_domain_action(action : lab_action) : string
  match action
    Load_board -> "b"
    Run_sync -> "y"
    Load_bridge_case(case_name) -> "l" ++ case_name
    Change_search_query(value) -> "i" ++ value
    Submit_search -> "s"
    Search_for(query) -> "q" ++ query
    Send_reply(incident_id, message) -> "r" ++ encode_action_field(incident_id.show) ++ "|" ++ encode_action_field(message)

fun decode_send_reply(payload : string) : maybe<lab_action>
  match split(payload, "|")
    [encoded_id, encoded_message] -> match decode_action_field(encoded_id)
      Nothing -> Nothing
      Just(id_text) -> match parse-int(id_text)
        Nothing -> Nothing
        Just(incident_id) -> decode_action_field(encoded_message).map(fn(message) Send_reply(incident_id, message))
    _ -> Nothing

fun decode_lab_domain_action(version : int, payload : string) : maybe<lab_action>
  if version != 2 then Nothing
  else if payload == "b" then Just(Load_board)
  else if payload == "y" then Just(Run_sync)
  else if payload == "s" then Just(Submit_search)
  else if payload != "" && payload.head == "l" then Just(Load_bridge_case(payload.tail))
  else if payload != "" && payload.head == "i" then Just(Change_search_query(payload.tail))
  else if payload != "" && payload.head == "q" then Just(Search_for(payload.tail))
  else if payload != "" && payload.head == "r" then decode_send_reply(payload.tail)
  else Nothing

pub val lab_action_codec : action_codec<lab_action> = Action_codec(
  schema = "lab/action",
  version = 2,
  decode = decode_lab_domain_action,
  encode = encode_lab_domain_action)

pub fun dispatch_lab_action(action : lab_action, owner : model) : <action_observation,lab_action_effect,div> model
  emit_action(source = "domain", target = "lab", codec = lab_action_codec, action = action)
  match action
    Load_board -> load_snapshot(owner)
    Run_sync -> perform_sync(owner)
    Load_bridge_case(case_name) -> start_bridge_case(owner, case_name)
    Change_search_query(value) -> set_search_query(owner, value)
    Submit_search -> start_search(owner)
    Search_for(query) -> pick_search_case(owner, query)
    Send_reply(incident_id, message) -> send_reply(owner, incident_id, message)

fun decode_lab_action(payload : string) : <div> maybe<lab_action>
  if payload == "lab-load" then
    Just(Load_board)
  else if payload == "lab-sync" then
    Just(Run_sync)
  else if payload == search_submit_payload() then
    Just(Submit_search)
  else
    decode_bridge_load_payload(payload).map(Load_bridge_case) ||
    decode_search_pick_payload(payload).map(Search_for)

pub fun route_lab_click(payload : string, owner : model) : <action_observation,lab_action_effect,div> maybe<model>
  decode_lab_action(payload).map(fn(action) dispatch_lab_action(action, owner)).or-else {
    resolve_search_result(owner, payload).or-else {
      resolve_bridge_result(owner, payload)
    }
  }

pub fun route_lab_input(channel : string, value : string, owner : model) : <bridge_request_effect,div> maybe<model>
  if channel == search_query_channel() then
    Just(set_search_query(owner, value))
  else Nothing
