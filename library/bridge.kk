module library/bridge

import explore/react/core

pub effect fun request_bridge_resource(payload : string, delay : int) : ()

pub struct bridge_signal
  resource_tag : string
  resource_key : string
  request_id : int

pub struct suspense_bridge_demo
  requested_case : string
  visible_case : string
  shell_status : string
  detail_status : string
  shell_request_id : int
  detail_request_id : int

pub struct bridge_case
  name : string
  label : string
  stage_note : string
  shell_title : string
  shell_summary : string
  detail_title : string
  detail_lines : list<string>
  shell_delay : int
  detail_delay : int

fun suspense_cases() : list<bridge_case>
  [
    Bridge_case(
      "edge-auth",
      "Edge Auth Bundle",
      "Outer boundary keeps the last visible incident brief while the browser callback resolves a newer auth snapshot.",
      "Auth bundle drift at the edge",
      "Two POPs are still serving an older login shell, so the demo keeps stale content on screen until the replacement shell lands.",
      "Nested diagnostics stream",
      [
        "cdn.trace: auth-shell-v42 is still hot in iad / hkg",
        "origin.diff: manifest hash moved from 7fd2 to 91ac",
        "mitigation: warm the new shell before swapping visible traffic",
      ],
      520,
      980),
    Bridge_case(
      "queue-drain",
      "Replay Queue Drain",
      "This case shows a slower outer shell and a faster nested payload once the queue owner flips.",
      "Replay queue ownership handoff",
      "The staging queue is rebalancing across workers, so the demo waits longer before revealing the next operator view.",
      "Queue replay trace",
      [
        "ingress: backlog crest detected after deploy wave 19",
        "scheduler: ownership moved to cache-safe workers",
        "replay: pressure drops only after the nested trace resolves",
      ],
      820,
      540),
    Bridge_case(
      "image-burst",
      "Thumbnail Burst",
      "The shell swaps quickly, but the nested diagnostics intentionally linger to mimic a second Suspense boundary.",
      "Thumbnail region warmup burst",
      "A new region is ready to reveal high-level status, while the per-stage trace keeps streaming under a nested fallback.",
      "Worker warmup detail",
      [
        "loader: region enters warm path after first request batch",
        "cache: derived variants refill after the shell is already visible",
        "tail-latency: final p95 settles only when nested detail completes",
      ],
      360,
      1180),
  ]

pub fun bridge_demo_cases() : list<bridge_case>
  suspense_cases()

pub fun default_bridge_case_name() : string
  "edge-auth"

pub fun initial_bridge_demo(requested_case : string) : suspense_bridge_demo
  Suspense_bridge_demo(requested_case, "", "idle", "idle", 0, 0)

pub fun start_bridge_shell_demo(demo : suspense_bridge_demo, case_name : string) : (suspense_bridge_demo, bool)
  val has_visible_case = demo.visible_case != ""
  (demo(
    requested_case = case_name,
    shell_status = if has_visible_case then "refreshing" else "pending",
    detail_status = if has_visible_case then demo.detail_status else "idle",
    shell_request_id = demo.shell_request_id + 1), has_visible_case)

pub fun start_bridge_detail_demo(demo : suspense_bridge_demo) : suspense_bridge_demo
  demo(detail_status = "pending", detail_request_id = demo.detail_request_id + 1)

pub fun bridge_shell_matches(demo : suspense_bridge_demo, case_name : string, request_id : int) : bool
  request_id == demo.shell_request_id && case_name == demo.requested_case

pub fun bridge_detail_matches(demo : suspense_bridge_demo, case_name : string, request_id : int) : bool
  request_id == demo.detail_request_id && case_name == demo.requested_case

pub fun resolve_bridge_shell_demo(demo : suspense_bridge_demo, case_name : string) : suspense_bridge_demo
  demo(visible_case = case_name, shell_status = "ready")

pub fun resolve_bridge_detail_demo(demo : suspense_bridge_demo) : suspense_bridge_demo
  demo(detail_status = "ready")

pub fun bridge_case_by_name(case_name : string) : <div> maybe<bridge_case>
  find(suspense_cases(), fn(item) bridge_case/name(item) == case_name)

pub fun bridge_shell_delay(case_name : string) : <div> int
  match bridge_case_by_name(case_name)
    Just(item) -> bridge_case/shell_delay(item)
    Nothing -> 600

pub fun bridge_detail_delay(case_name : string) : <div> int
  match bridge_case_by_name(case_name)
    Just(item) -> bridge_case/detail_delay(item)
    Nothing -> 900

pub fun bridge_load_payload(resource_key : string) : string
  "bridge-load|" ++ resource_key

pub fun decode_bridge_load_payload(payload : string) : <div> maybe<string>
  match split(payload, "|")
    ["bridge-load", resource_key] -> Just(resource_key)
    _ -> Nothing

pub fun bridge_result_payload(resource_kind : string, resource_key : string, request_id : int) : string
  "bridge-" ++ resource_kind ++ "|" ++ resource_key ++ "|" ++ request_id.show

pub fun decode_bridge_result_payload(payload : string) : <div> maybe<bridge_signal>
  match split(payload, "|")
    [resource_tag, resource_key, request_id_text] -> parse-int(request_id_text).map(fn(request_id) Bridge_signal(resource_tag, resource_key, request_id))
    _ -> Nothing

pub fun request_bridge_result(resource_kind : string, resource_key : string, request_id : int, delay : int) : <request_bridge_resource,div> ()
  request_bridge_resource(bridge_result_payload(resource_kind, resource_key, request_id), delay)

pub fun render_bridge_fallback(key : string, title : string, note : string, class_name : string) : <div> vnode
  div([
    strong(title, class = "bridge-fallback-title"),
    p(note, class = "case-detail"),
    div([
      span("", class = "bridge-bar bridge-bar-wide"),
      span("", class = "bridge-bar bridge-bar-mid"),
      span("", class = "bridge-bar bridge-bar-short"),
    ], class = "bridge-fallback-bars"),
  ], key = key, class = "bridge-fallback " ++ class_name)

fun bridge_case_button<e::E>(item : bridge_case, requested_case : string, visible_case : string, on_select : string -> <div|e> listener) : <div|e> vnode
  val case_name = bridge_case/name(item)
  val class_name =
    if case_name == visible_case then "button button-active"
    else if case_name == requested_case then "button button-primary bridge-button-pending"
    else "button"
  button(bridge_case/label(item), class = class_name, click = on_select(case_name))

pub fun render_bridge_case_buttons<e::E>(items : list<bridge_case>, requested_case : string, visible_case : string, on_select : string -> <div|e> listener) : <div|e> list<vnode>
  map(items, fn(item) bridge_case_button(item, requested_case, visible_case, on_select))

fun bridge_transition_banner(requested_case : string, visible_case : string) : vnode
  div([
    div([
      strong("Transition keeps stale content visible", class = "bridge-fallback-title"),
      span("refreshing", class = "incident-status incident-status-investigating"),
    ], class = "bridge-transition-head"),
    p("Currently showing `" ++ visible_case ++ "` while the browser bridge resolves `" ++ requested_case ++ "` in the background.", class = "case-detail"),
    div([
      span("visible: " ++ visible_case, class = "bridge-token bridge-token-current"),
      span("->", class = "bridge-arrow-token"),
      span("next: " ++ requested_case, class = "bridge-token bridge-token-next"),
    ], class = "bridge-transition-rail"),
  ], class = "bridge-transition-banner")

fun bridge_detail_node(case_item : bridge_case, detail_status : string) : <div> vnode
  if detail_status == "ready" then
    div([
      strong(bridge_case/detail_title(case_item), class = "section-title"),
      p("Nested boundary resolved after the outer shell became visible.", class = "case-detail"),
      ul(map-indexed(bridge_case/detail_lines(case_item), fn(index, line) li_text(line, key = "bridge-detail-" ++ index.show, class = "activity-item")), class = "activity-list"),
    ], class = "bridge-detail-card")
  else
    render_bridge_fallback("bridge-detail-fallback", title = "Nested fallback", note = "Shell is visible, but the diagnostic trace is still suspended through the browser callback bridge.", class_name = "bridge-detail-fallback")

fun bridge_shell_node(case_item : bridge_case, requested_case : string, visible_case : string, shell_status : string, detail_status : string) : <div> vnode
  val is_refreshing = shell_status == "refreshing"
  val shell_class = if is_refreshing then "bridge-shell-card bridge-shell-refreshing" else "bridge-shell-card"
  val status_text = if is_refreshing then "showing stale shell while requesting `" ++ requested_case ++ "`" else "outer boundary resolved"
  val body_children = if is_refreshing then
    [
      div([
        div([
          strong(bridge_case/shell_title(case_item), class = "section-title"),
          p(bridge_case/shell_summary(case_item), class = "case-detail"),
        ], class = "stack"),
        div([
          span(status_text, class = "incident-status incident-status-investigating"),
        ], class = "bridge-shell-badges"),
      ], class = "bridge-shell-head"),
      bridge_transition_banner(requested_case, visible_case),
      p(bridge_case/stage_note(case_item), class = "bridge-state-note"),
      bridge_detail_node(case_item, detail_status),
    ]
  else
    [
      div([
        div([
          strong(bridge_case/shell_title(case_item), class = "section-title"),
          p(bridge_case/shell_summary(case_item), class = "case-detail"),
        ], class = "stack"),
        div([
          span(status_text, class = "incident-status incident-status-investigating"),
        ], class = "bridge-shell-badges"),
      ], class = "bridge-shell-head"),
      p(bridge_case/stage_note(case_item), class = "bridge-state-note"),
      bridge_detail_node(case_item, detail_status),
    ]
  article(body_children, class = shell_class)

pub fun render_bridge_stage(selected_case : maybe<bridge_case>, requested_note : string, requested_case : string, visible_case : string, shell_status : string, detail_status : string) : <div> vnode
  match selected_case
    Just(case_item) -> if visible_case == "" && shell_status != "ready" then
      render_bridge_fallback("bridge-shell-fallback", title = "Outer fallback", note = requested_note, class_name = "bridge-shell-fallback")
    else
      bridge_shell_node(case_item, requested_case, visible_case, shell_status, detail_status)
    Nothing -> div([
      strong("Suspense-like bridge demo", class = "section-title"),
      p("Select a case to trigger a browser callback that resolves the shell and nested diagnostics in two stages.", class = "case-detail"),
    ], class = "bridge-empty")

pub fun render_bridge_panel<e::E>(demo : suspense_bridge_demo, summary : (string, string) -> vnode, on_select : string -> <div|e> listener) : <div|e> vnode
  val requested_case = demo.requested_case
  val visible_case = demo.visible_case
  val selected_case = if visible_case == "" then requested_case else visible_case
  val requested_note = match bridge_case_by_name(requested_case)
    Just(case_item) -> bridge_case/stage_note(case_item)
    Nothing -> "Select a bridge case to start the suspense-like demo."
  section([
    div([
      div([
        strong("Suspense-like bridge demo", class = "section-title"),
        p("This keeps stale shell content visible while a browser callback resolves the next case, then reveals nested detail through a second fallback.", class = "case-detail"),
      ], class = "stack"),
      div([
        summary("Requested", requested_case),
        summary("Visible", if visible_case == "" then "<fallback>" else visible_case),
        summary("Shell", demo.shell_status),
        summary("Detail", demo.detail_status),
      ], class = "summary-row bridge-meta"),
    ], class = "bridge-panel-head"),
    div(render_bridge_case_buttons(bridge_demo_cases(), requested_case = requested_case, visible_case = visible_case, on_select = on_select), class = "button-row bridge-case-row"),
    render_bridge_stage(bridge_case_by_name(selected_case), requested_note = requested_note, requested_case = requested_case, visible_case = visible_case, shell_status = demo.shell_status, detail_status = demo.detail_status),
  ], key = "lab-bridge", class = "bridge-panel")
