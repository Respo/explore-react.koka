module library/search

import explore/react/core

pub struct search_case
  query : string
  label : string
  summary : string
  result_delay : int
  timeout_delay : int

pub struct search_menu_item
  title : string
  route_hint : string
  note : string
  query_hint : string
  keywords : list<string>

pub struct search_demo
  query_input : string
  requested_query : string
  visible_query : string
  status : string
  timeout_status : string
  auto_status : string
  request_id : int
  auto_request_id : int
  results : list<string>
  stage_note : string

pub fun initial_search_demo(query_input : string, stage_note : string) : search_demo
  Search_demo(query_input, "", "", "idle", "idle", "idle", 0, 0, Nil, stage_note)

fun search_cases() : list<search_case>
  [
    Search_case(
      "edge",
      "Edge cache",
      "Fast enough to beat the timeout budget, useful for the happy path.",
      180,
      420),
    Search_case(
      "queue",
      "Replay queue",
      "Timeout wins first, then the server result recovers later.",
      760,
      320),
    Search_case(
      "image",
      "Image burst",
      "Near-threshold latency to exercise interleaving and stale ignore cases.",
      460,
      300),
    Search_case(
      "dialog",
      "Dialog overlay",
      "Extra catalog keyword that proves search results now come from menu data instead of hardcoded copy.",
      280,
      360),
  ]

fun menu_catalog() : list<search_menu_item>
  [
    Search_menu_item(
      "Edge auth bundle",
      "#lab-bridge",
      "Staged shell/detail bridge around auth drift at the edge POPs.",
      "edge",
      ["edge", "auth", "cache", "login"]),
    Search_menu_item(
      "Edge rollout timeline",
      "#lab-bridge",
      "Transition timeline for warmup, rollout, and stale-shell recovery.",
      "edge",
      ["edge", "rollout", "traffic", "warmup"]),
    Search_menu_item(
      "Queue drain console",
      "#lab-bridge",
      "Replay ownership handoff and worker drain visibility.",
      "queue",
      ["queue", "replay", "worker", "drain"]),
    Search_menu_item(
      "Queue ownership audit",
      "#lab-board",
      "Backpressure notes for cache-safe ownership swaps.",
      "queue",
      ["queue", "ownership", "backpressure", "cache-safe"]),
    Search_menu_item(
      "Image burst monitor",
      "#lab-bridge",
      "Thumbnail worker warmup under burst traffic.",
      "image",
      ["image", "thumbnail", "burst", "warmup"]),
    Search_menu_item(
      "Image variant cache",
      "#lab-board",
      "Derived variant refill and cache tail-latency notes.",
      "image",
      ["image", "variant", "thumbnail", "cache"]),
    Search_menu_item(
      "Dialog overlay drawer",
      "#effects-dialogs",
      "Dismiss bridge, ESC support, and animated drawer exit.",
      "dialog",
      ["dialog", "drawer", "overlay", "escape"]),
    Search_menu_item(
      "Prompt validation flow",
      "#effects-dialogs",
      "Prompt focus effect and validation round-trip.",
      "dialog",
      ["dialog", "prompt", "overlay", "validation"]),
  ]

fun compact_terms(parts : list<string>) : list<string>
  match parts
    Nil -> Nil
    Cons(part, rest) -> if part == "" then compact_terms(rest) else Cons(part, compact_terms(rest))

fun string_has_prefix(value : string, query : string) : bool
  is-just(starts-with(to-lower(value), query))

fun item_prefix_matches(item : search_menu_item, query : string) : bool
  val q = to-lower(trim(query))
  if q == "" then True
  else
    string_has_prefix(search_menu_item/title(item), q) ||
    string_has_prefix(search_menu_item/route_hint(item), q) ||
    any(search_menu_item/keywords(item), fn(keyword) string_has_prefix(keyword, q))

fun matched_menu_items(items : list<search_menu_item>, query : string) : <div> list<search_menu_item>
  match items
    Nil -> Nil
    Cons(item, rest) -> {
      val next = matched_menu_items(rest, query)
      if search_menu_matches_query(item, query) then Cons(item, next) else next
    }

fun menu_result_line(item : search_menu_item) : string
  search_menu_item/title(item) ++ " -> " ++ search_menu_item/route_hint(item) ++ " | " ++ search_menu_item/note(item)

pub fun search_demo_cases() : list<search_case>
  search_cases()

pub fun search_menu_items() : list<search_menu_item>
  menu_catalog()

pub fun default_search_query() : string
  "edge"

pub fun search_case_by_query(query : string) : <div> maybe<search_case>
  find(search_cases(), fn(item) search_case/query(item) == query)

pub fun search_auto_delay() : int
  300

pub fun search_result_delay(query : string) : <div> int
  match search_case_by_query(query)
    Just(item) -> search_case/result_delay(item)
    Nothing -> 360

pub fun search_timeout_delay(query : string) : <div> int
  match search_case_by_query(query)
    Just(item) -> search_case/timeout_delay(item)
    Nothing -> 340

pub fun search_result_lines(query : string) : <div> list<string>
  match matched_menu_items(menu_catalog(), query)
    Nil -> [
      "No menu item matched `" ++ query ++ "` yet.",
      "Try catalog keywords like `edge`, `queue`, `image`, or `dialog`.",
      "Auto search still uses the same suspense-lite timer and stale-result guards.",
    ]
    items -> map(items, menu_result_line)

pub fun search_case_summary(query : string) : <div> string
  match search_case_by_query(query)
    Just(item) -> search_case/summary(item)
    Nothing -> "Generic query routed through the suspense-lite search demo."

pub fun search_menu_matches_query(item : search_menu_item, query : string) : <div> bool
  item_prefix_matches(item, query)

fun search_dropdown_item(item : search_menu_item, index : int, dispatch_search : string -> listener) : <div> vnode
  div_key("search-drop-" ++ index.show, props(class = "search-dropdown-item"), [
    button(props(class = "search-item-btn"), on(click = dispatch_search(search_menu_item/query_hint(item))), search_menu_item/title(item)),
    span(props(class = "search-item-hint"), search_menu_item/route_hint(item)),
  ])

fun render_search_dropdown(items : list<search_menu_item>, dispatch_search : string -> listener) : <div> list<vnode>
  map-indexed(items, fn(index, item) search_dropdown_item(item, index, dispatch_search))

pub fun render_search_panel(demo : search_demo, dispatch_submit : listener, dispatch_search : string -> listener) : <div> vnode
  val items = if demo.visible_query == "" then menu_catalog() else matched_menu_items(menu_catalog(), demo.visible_query)
  val dropdown =
    if is-nil(items) then
      div(props(class = "search-dropdown-hidden"), Nil)
    else
      div(props(class = "search-dropdown"), render_search_dropdown(items, dispatch_search))
  section_key("lab-search", props(class = "search-panel"), [
    div(props(class = "search-input-wrap"), [
      div(props(class = "composer-row"), [
        input_text_key(search_query_channel(), props(class = "input search-input"), on(input = input_listener(search_query_channel()), enter = dispatch_submit), demo.query_input, "Search by keyword..."),
      ]),
      dropdown,
    ]),
  ])

pub fun should_arm_auto_search(demo : search_demo, trimmed : string) : bool
  if trimmed == "" then
    False
  else if demo.status == "ready" && trimmed == demo.visible_query then
    False
  else if trimmed == demo.requested_query && demo.status != "idle" && demo.status != "timed_out" then
    False
  else
    True

pub fun search_query_channel() : string
  "lab-search-query"

pub fun search_submit_payload() : string
  "lab-search-submit"

pub fun search_pick_payload(query : string) : string
  "lab-search-pick|" ++ query

pub fun decode_search_pick_payload(payload : string) : <div> maybe<string>
  match split(payload, "|")
    ["lab-search-pick", query] -> Just(query)
    _ -> Nothing

pub fun prepare_search_query_update(demo : search_demo, value : string, idle_note : string, armed_note : string, visible_note : string) : <div> (search_demo, bool)
  val trimmed = trim(value)
  if trimmed == "" then
    (demo(
      query_input = value,
      requested_query = "",
      visible_query = "",
      status = "idle",
      timeout_status = "idle",
      auto_status = "idle",
      results = Nil,
      stage_note = idle_note), False)
  else {
    val should_arm = should_arm_auto_search(demo, trimmed)
    val next_auto_request_id = if should_arm then demo.auto_request_id + 1 else demo.auto_request_id
    (demo(
      query_input = value,
      auto_status = if should_arm then "armed" else "idle",
      auto_request_id = next_auto_request_id,
      stage_note = if should_arm then armed_note else if demo.status == "ready" && trimmed == demo.visible_query then visible_note else demo.stage_note), should_arm)
  }

pub fun prepare_search_start(demo : search_demo, query : string, pending_note : string, refreshing_note : string) : (search_demo, bool)
  val next_request_id = demo.request_id + 1
  val has_visible = demo.visible_query != ""
  (demo(
    requested_query = query,
    status = if has_visible then "refreshing" else "pending",
    timeout_status = "pending",
    auto_status = "idle",
    request_id = next_request_id,
    results = if has_visible then demo.results else Nil,
    stage_note = if has_visible then refreshing_note else pending_note), has_visible)

pub fun search_auto_matches(demo : search_demo, query : string, signal_auto_request_id : int) : bool
  demo.auto_status == "armed" && signal_auto_request_id == demo.auto_request_id && query == trim(demo.query_input)

pub fun clear_search_auto(demo : search_demo) : search_demo
  demo(auto_status = "idle")

pub fun search_auto_should_start(demo : search_demo, query : string) : bool
  not(query == demo.requested_query && demo.status != "idle" && demo.status != "timed_out")

pub fun search_request_matches(demo : search_demo, query : string, signal_request_id : int) : bool
  signal_request_id == demo.request_id && query == demo.requested_query

pub fun apply_search_timeout(demo : search_demo, timed_out_note : string, stale_visible_note : string) : maybe<(search_demo, bool)>
  if demo.status == "ready" then
    Nothing
  else {
    val has_visible = demo.visible_query != ""
    Just((demo(
      timeout_status = "timed_out",
      status = if has_visible then "refreshing" else "timed_out",
      stage_note = if has_visible then stale_visible_note else timed_out_note), has_visible))
  }

pub fun apply_search_result(demo : search_demo, query : string, results : list<string>, recovered_note : string, resolved_note : string) : (search_demo, bool)
  val recovered = demo.timeout_status == "timed_out"
  (demo(
    visible_query = query,
    status = "ready",
    timeout_status = "idle",
    auto_status = "idle",
    results = results,
    stage_note = if recovered then recovered_note else resolved_note), recovered)

