module demo/model

import library/bridge
import library/dialog
import library/route
import library/search
import explore/react/action
import explore/react/state

pub type incident_severity
  Severity_p1
  Severity_p2
  Severity_p3

pub fun show_severity(s : incident_severity) : string
  match s
    Severity_p1 -> "p1"
    Severity_p2 -> "p2"
    Severity_p3 -> "p3"

pub type incident_status
  Status_firing
  Status_investigating
  Status_acked

pub fun show_status(s : incident_status) : string
  match s
    Status_firing -> "firing"
    Status_investigating -> "investigating"
    Status_acked -> "acked"

pub effect browser_host
  fun confirm_action(message : string) : bool
  fun audit(message : string) : ()
  val current_operator : string
  fun wait_ms(delay : int) : ()
  fun fetch_lab_snapshot() : lab_snapshot
  fun post_lab_reply(incident_id : int, message : string) : string
  fun now_label() : string

pub effect val current_filter : string

pub alias filter_context_effect = <current_filter>
pub alias dialog_host_effect = <browser_host>
pub alias bridge_request_effect = <request_bridge_resource>
pub alias bridge_demo_effect = <browser_host,request_bridge_resource>
pub alias snapshot_host_effect = <browser_host>
pub alias sync_host_effect = <browser_host>
pub alias reply_host_effect = <browser_host>
pub alias lab_action_effect = <browser_host,request_bridge_resource>
pub alias browser_event_effect = <action_observation,browser_host,request_bridge_resource,local_state_read,local_state_write>

pub struct task
  id : int
  title : string
  done : bool

pub struct incident
  id : int
  title : string
  severity : incident_severity
  status : incident_status
  summary : string
  server_note : string
  updated_by : string

pub struct lab_snapshot
  incidents : list<incident>
  summary : string

pub struct workflow_lab
  incidents : list<incident>
  activity_log : list<string>
  sync_status : string
  last_sync_label : string
  bridge_demo : suspense_bridge_demo
  search_demo : search_demo

pub struct model
  tasks : list<task>
  draft : string
  next_id : int
  filter_name : string
  notice : string
  route_name : string
  lab : workflow_lab
  dialog : dialog_demo

fun task_visible(item : task) : filter_context_effect bool
  if current_filter == "active" then not(item.done)
  else if current_filter == "done" then item.done
  else True

pub fun visible_tasks(tasks : list<task>) : <filter_context_effect,div> list<task>
  filter(tasks, task_visible)

pub fun tasks_for(filter_name : string, tasks : list<task>) : <div> list<task>
  with val current_filter = filter_name
  visible_tasks(tasks)

pub val route_action_codec : action_codec<route_action> = Action_codec(
  schema = "app/route-action",
  version = 1,
  decode = fn(version, payload) if version == 1 then decode_route_action(payload) else Nothing,
  encode = route_action_payload)

pub fun dispatch_route_action(action : route_action, item : model) : <action_observation,div> model
  val route_name = normalize_route(route_action_target(action))
  emit_action(source = "domain", target = "app/route", codec = route_action_codec, action = action)
  item(route_name = route_name)

pub fun handle_route_click(payload : string, item : model) : <action_observation,div> maybe<model>
  decode_route_action(payload).map(fn(action) dispatch_route_action(action, item))

// Route changes remain data-only; render-time hooks now decide whether to execute browser effects.
pub fun reduce_click(payload : string, item : model) : <action_observation,browser_host,div> model
  match handle_route_click(payload, item)
    Just(next_item) -> next_item
    Nothing -> item(notice = "Unknown action: " ++ payload)

pub fun reduce_input(channel : string, value : string, item : model) : <div> model
  item(notice = "Unhandled input channel: " ++ channel ++ " = " ++ value)
