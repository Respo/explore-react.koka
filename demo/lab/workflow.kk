module demo/lab/workflow

import demo/model
import demo/runtimeowner
import demo/lab/state
import library/bridge
import explore/react/state

fun append_lines(lines : list<string>, value : string) : <div> list<string>
  match lines
    Nil -> [value]
    Cons(head, rest) -> Cons(head, append_lines(rest, value))

fun append_lab_activity(lab : workflow_lab, line : string) : <div> workflow_lab
  lab(activity_log = append_lines(lab.activity_log, line))

fun start_bridge_shell(owner : model, case_name : string) : <bridge_demo_effect,div> model
  match bridge_case_by_name(case_name)
    Nothing -> owner(notice = "Unknown bridge demo case: " ++ case_name)
    Just(_case_item) -> {
      val lab = owner.lab
      val (next_demo, has_visible_case) = start_bridge_shell_demo(lab.bridge_demo, case_name)
      request_bridge_result("shell", case_name, next_demo.shell_request_id, bridge_shell_delay(case_name))
      audit("Scheduled suspense-like shell bridge for `" ++ case_name ++ "`.")
      val next_lab = append_lab_activity(lab(bridge_demo = next_demo), "[bridge] shell pending for " ++ case_name)
      owner(lab = next_lab, notice = if has_visible_case then "Bridge demo is refreshing while keeping stale content visible." else "Bridge demo entered the outer fallback state.")
    }

fun start_bridge_detail(owner : model, case_name : string) : <bridge_demo_effect,div> model
  val lab = owner.lab
  val next_demo = start_bridge_detail_demo(lab.bridge_demo)
  request_bridge_result("detail", case_name, next_demo.detail_request_id, bridge_detail_delay(case_name))
  audit("Scheduled suspense-like detail bridge for `" ++ case_name ++ "`.")
  val next_lab = append_lab_activity(lab(bridge_demo = next_demo), "[bridge] nested detail pending for " ++ case_name)
  owner(lab = next_lab, notice = "Outer shell resolved; nested diagnostics are still loading.")

pub fun resolve_bridge_result(owner : model, payload : string) : <bridge_demo_effect,div> maybe<model>
  maybe(decode_bridge_result_payload(payload), Nothing, fn(signal) {
    match signal
      Bridge_signal(resource_tag, case_name, request_id) -> {
        val lab = owner.lab
        val demo = lab.bridge_demo
        if resource_tag == "bridge-shell" then
          if not(bridge_shell_matches(demo, case_name, request_id)) then
            Just(owner)
          else
            Just(resolve_bridge_shell(owner, case_name))
        else if resource_tag == "bridge-detail" then
          if not(bridge_detail_matches(demo, case_name, request_id)) then
            Just(owner)
          else {
            audit("Nested suspense-like detail resolved for `" ++ case_name ++ "`.")
            val next_demo = resolve_bridge_detail_demo(demo)
            val next_lab = append_lab_activity(lab(bridge_demo = next_demo), "[bridge] nested detail ready for " ++ case_name)
            Just(owner(lab = next_lab, notice = "Nested diagnostics resolved after the shell became visible."))
          }
        else Nothing
      }
  })

fun update_incident_reply(items : list<incident>, target_id : int, message : string, updated_by : string) : <div> list<incident>
  match items
    Nil -> Nil
    Cons(item, rest) ->
      val next_rest = update_incident_reply(rest, target_id, message, updated_by)
      if incident/id(item) == target_id then
        Cons(Incident(incident/id(item), item.title, item.severity, Status_acked, item.summary, message, updated_by), next_rest)
      else
        Cons(item, next_rest)

pub fun load_snapshot(item : model) : <snapshot_host_effect,div> model
  audit("Loaded workflow lab snapshot from a mocked server handler.")
  val snapshot = fetch_lab_snapshot()
  val stamp = now_label()
  val lab = item.lab
  val next_lab = lab(
    incidents = snapshot.incidents,
    activity_log = append_lines(lab.activity_log, "[" ++ stamp ++ "] " ++ snapshot.summary),
    sync_status = "loaded",
    last_sync_label = stamp)
  item(lab = next_lab, notice = "Workflow lab loaded mock server data.")

pub fun perform_sync(item : model) : <sync_host_effect,div> model
  audit("Started staged sync for workflow lab.")
  wait_ms(30)
  val snapshot = fetch_lab_snapshot()
  wait_ms(90)
  val stamp = now_label()
  val lab = item.lab
  val next_lab = lab(
    incidents = snapshot.incidents,
    activity_log = append_lines(lab.activity_log, "[" ++ stamp ++ "] sync: " ++ snapshot.summary),
    sync_status = "synced",
    last_sync_label = stamp)
  item(lab = next_lab, notice = "Workflow lab sync finished through algebraic effects.")

pub fun send_reply(item : model, incident_id : int) : <reply_host_effect,div> model
  val lab = item.lab
  val draft = lab_incident_draft(runtimeowner/attached_runtime_tree(item), incident_id)
  if draft == "" then
    item(notice = "Draft is empty for this incident card.")
  else
    match find(lab.incidents, fn(found) incident_id == incident/id(found))
      Nothing -> item(notice = "Incident not found in workflow lab.")
      Just(_found) -> {
        audit("Sending workflow lab reply for incident #" ++ incident_id.show)
        wait_ms(40)
        val server_reply = post_lab_reply(incident_id, draft)
        wait_ms(20)
        val stamp = now_label()
        val operator = current_operator
        val next_tree = finalize_incident_reply_tree(runtimeowner/attached_runtime_tree(item), incident_id)
        val next_incidents = update_incident_reply(lab.incidents, incident_id, draft, operator ++ " @ " ++ stamp)
        val next_logs = append_lines(lab.activity_log, "[" ++ stamp ++ "] " ++ server_reply)
        val next_lab = lab(incidents = next_incidents, activity_log = next_logs, sync_status = "reply-sent", last_sync_label = stamp)
        runtimeowner/attach_runtime_tree(item(lab = next_lab, notice = "Workflow lab reply sent with mocked server effect."), next_tree)
      }

pub fun resolve_bridge_shell(owner : model, case_name : string) : <bridge_demo_effect,div> model
  val lab = owner.lab
  val next_demo = resolve_bridge_shell_demo(lab.bridge_demo, case_name)
  val next_lab = append_lab_activity(lab(bridge_demo = next_demo), "[bridge] shell ready for " ++ case_name)
  start_bridge_detail(owner(lab = next_lab), case_name)

pub fun start_bridge_case(owner : model, case_name : string) : <bridge_demo_effect,div> model
  start_bridge_shell(owner, case_name)