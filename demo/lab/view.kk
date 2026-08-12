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

alias lab_view_effect = <hook_scope,lab_local_effect,listener_registry<model,browser_event_effect>>

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
  val (expanded, _set_expanded) = use_state_pair(flag_state_codec, False)
  val (draft, _set_draft) = use_state_pair(text_state_codec, "")
  val toggle_label = if expanded then "Collapse" else "Expand"
  val preview_text = if draft == "" then "local draft: <empty>" else "local draft: " ++ draft
  val collapsed_text = if draft == "" then "Draft is local and still empty." else "Draft saved locally for this card."
  val detail_node = if expanded then
    div(props(class = "incident-detail-grid"), [
      p(props(class = "mono"), "server: " ++ item.server_note),
      p(props(class = "mono"), "updated by: " ++ item.updated_by),
      p(props(class = "mono"), preview_text),
    ])
  else
    p(props(class = "mono"), collapsed_text)
  article_key("incident-" ++ iid.show, props(class = "incident-card"), [
    div(props(class = "incident-head"), [
      div(props(class = "incident-title-wrap"), [
        strong(props(class = "incident-title"), item.title),
        span(props(class = "case-detail"), item.summary),
      ]),
      div(props(class = "incident-badges"), [
        span(props(class = severity_class(item)), item.severity.show_severity),
        span(props(class = status_class(item)), item.status.show_status),
      ]),
    ]),
    div(props(class = "incident-controls"), [
      button(props(class = "button"), on(click = on_local_click("toggle-expanded", fn(owner : model) commit_lab_tree(owner, fn() toggle_local_lab_expanded(owner, iid)))), toggle_label),
      input_text_key("lab-draft-" ++ iid.show, props(class = "input incident-input"), on(
        input = on_local_input("draft-input", fn(value, owner : model) commit_lab_tree(owner, fn() set_local_lab_draft(owner, iid, value))),
        enter = on_local_enter("send-reply", fn(owner : model) dispatch_lab_action(Send_reply(iid), owner))), draft, "Local reply draft, per card..."),
      button(props(class = "button button-primary"), on(click = on_local_click("send-reply", fn(m : model) dispatch_lab_action(Send_reply(iid), m))), "Send reply"),
    ]),
    detail_node,
  ])

fun render_incident_cards(items : list<incident>) : lab_view_effect list<vnode>
  map(items, fn(item) component_in("incidents", incident/id(item).show, fn() incident_card(item)))

fun incident_grid(lab : workflow_lab) : lab_view_effect vnode
  div(props(class = "incident-grid"), render_incident_cards(lab.incidents))

fun render_activity_items(lines : list<string>) : <div> list<vnode>
  map-indexed(lines, fn(index, line) li_text_key("activity-" ++ index.show, props(class = "activity-item"), line))

fun activity_panel(lab : workflow_lab) : <div> vnode
  aside(props(class = "mini-panel activity-panel"), [
    strong(props, "Workflow activity"),
    p(props(class = "case-detail"), "Each sync or reply appends a line that can be asserted in tests."),
    ul(props(class = "activity-list"), render_activity_items(lab.activity_log)),
  ])

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
      div(props(class = "button-row"), [
        button(props(class = "button"), on(click = on_local_click("load-board", fn(m : model) dispatch_lab_action(Load_board, m))), "Load mock board"),
        button(props(class = "button button-primary"), on(click = on_local_click("run-sync", fn(m : model) dispatch_lab_action(Run_sync, m))), "Run staged sync"),
        span(props(class = "mono"), "status: " ++ lab.sync_status),
      ]),
      div(props(class = "lab-body-grid"), [
        incident_grid(lab),
        activity_panel(lab),
      ]),
    ]

pub fun render_lab_panel(item : model, runtime_tree : list<state_entry>) : lab_view_effect vnode
  val lab = item.lab
  val children = [
    div(props(class = "summary-row"), [
      summary_chip("Incidents", length(lab.incidents).show),
      summary_chip("Open", length(filter(lab.incidents, fn(incident_item) match incident_item.status { Status_acked -> False; _ -> True })).show),
      summary_chip("Drafts", length(filter(lab.incidents, fn(incident_item) lab_incident_draft(runtime_tree, incident/id(incident_item)) != "")).show),
      summary_chip("Local cells", count_entries(runtime_tree).show),
      summary_chip("Last sync", lab.last_sync_label),
    ]),
  ] ++ lab_panel_sections(item.route_name, lab)
  panel("Workflow lab", lab_panel_note(item.route_name), "lab", "lab-panel", children)
