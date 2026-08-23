module demo/lab/view

import demo/model
import demo/lab/events
import demo/lab/search
import demo/shared
import demo/lab/state
import library/bridge
import library/search
import explore/react/core
import explore/react/state

alias lab_view_effect = <hook_scope,local_state_read,listener_registry<model,browser_event_effect>,div>

fun severity_class(item : incident) : string
  match item.severity
    Severity_p1 -> "incident-severity incident-severity-p1"
    Severity_p2 -> "incident-severity incident-severity-p2"
    Severity_p3 -> "incident-severity incident-severity-p3"

fun status_class(item : incident) : string
  match item.status
    Status_acked -> "incident-status incident-status-acked"
    Status_investigating -> "incident-status incident-status-investigating"
    Status_firing -> "incident-status incident-status-firing"

fun incident_card(item : incident) : lab_view_effect vnode
  val iid = incident/id(item)
  val local = use_store(incident_local_store, initial = Incident_local_state(False, ""))
  val Incident_local_state(expanded, draft) = local.current
  val toggle_label = if expanded then "Collapse" else "Expand"
  val preview_text = if draft == "" then "local draft: <empty>" else "local draft: " ++ draft
  val collapsed_text = if draft == "" then "Draft is local and still empty." else "Draft saved locally for this card."
  val detail_node = if expanded then
    div([
      p("server: " ++ item.server_note, class = "mono"),
      p("updated by: " ++ item.updated_by, class = "mono"),
      p(preview_text, class = "mono"),
    ], class = "incident-detail-grid")
  else
    p(collapsed_text, class = "mono")
  article([
    div([
      div([
        strong(item.title, class = "incident-title"),
        span(item.summary, class = "case-detail"),
      ], class = "incident-title-wrap"),
      div([
        span(item.severity.show_severity, class = severity_class(item)),
        span(item.status.show_status, class = status_class(item)),
      ], class = "incident-badges"),
    ], class = "incident-head"),
    div([
      button(toggle_label, class = "button", click = on_store_click("toggle-expanded", local, Toggle_incident)),
      input_text(draft, key = "lab-draft-" ++ iid.show, class = "input incident-input", input = on_store_input("draft-input", local, Change_incident_draft), enter = on_local_enter("send-reply", fn(owner : model) dispatch_lab_action(Send_reply(iid), owner)), placeholder = "Local reply draft, per card..."),
      button("Send reply", class = "button button-primary", click = on_local_click("send-reply", fn(m : model) dispatch_lab_action(Send_reply(iid), m))),
    ], class = "incident-controls"),
    detail_node,
  ], key = "incident-" ++ iid.show, class = "incident-card")

fun incident_grid(lab : workflow_lab) : lab_view_effect vnode
  div(components(lab.incidents, group = "incidents", key = fn(item) incident/id(item).show, render = incident_card), class = "incident-grid")

fun activity_panel(lab : workflow_lab) : <div> vnode
  aside([
    strong("Workflow activity"),
    p("Each sync or reply appends a line that can be asserted in tests.", class = "case-detail"),
    ul(map-indexed(lab.activity_log, fn(index, line) li_text(line, key = "activity-" ++ index.show, class = "activity-item")), class = "activity-list"),
  ], class = "mini-panel activity-panel")

fun lab_panel_note(route_name : string) : string
  if route_name == "lab-search" then "Search is isolated here so debounced auto-run, timeout racing, stale-result retention, and the menu catalog are easier to inspect by themselves."
  else if route_name == "lab-bridge" then "Bridge is isolated here so the staged shell/detail suspense-like behavior is not competing with the workflow board or search demo."
  else "Board keeps the incident workflow, local drafts, activity log, and staged sync actions together without the search and bridge demos crowding the same page."

fun lab_panel_sections(route_name : string, lab : workflow_lab) : lab_view_effect list<vnode>
  if route_name == "lab-search" then {
    val submit_listener = on_local_enter("submit-search", fn(m : model) dispatch_lab_action(Submit_search, m))
    [render_search_panel(lab.search_demo, submit_listener, fn(query) dispatch_lab_click(Search_for(query)))]
  }
  else if route_name == "lab-bridge" then
    [render_bridge_panel(lab.bridge_demo, summary_chip, fn(case_name) dispatch_lab_click(Load_bridge_case(case_name)))]
  else
    [
      div([
        button("Load mock board", class = "button", click = on_local_click("load-board", fn(m : model) dispatch_lab_action(Load_board, m))),
        button("Run staged sync", class = "button button-primary", click = on_local_click("run-sync", fn(m : model) dispatch_lab_action(Run_sync, m))),
        span("status: " ++ lab.sync_status, class = "mono"),
      ], class = "button-row"),
      div([
        incident_grid(lab),
        activity_panel(lab),
      ], class = "lab-body-grid"),
    ]

pub fun render_lab_panel(item : model) : lab_view_effect vnode
  val lab = item.lab
  val children = [
    div([
      summary_chip("Incidents", length(lab.incidents).show),
      summary_chip("Open", length(filter(lab.incidents, fn(incident_item) match incident_item.status { Status_acked -> False; _ -> True })).show),
      summary_chip("Last sync", lab.last_sync_label),
    ], class = "summary-row"),
  ] ++ lab_panel_sections(item.route_name, lab)
  panel(children, title = "Workflow lab", note = lab_panel_note(item.route_name), key = "lab", class_name = "lab-panel")
