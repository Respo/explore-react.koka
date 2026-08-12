module demo/lab/search

import demo/model
import demo/seed
import library/bridge
import library/search

fun search_idle_note() : string
  "Type a query, pause to auto-search the menu catalog, keep stale results visible during refresh, and let timeout race against the mocked server response."

fun append_search_activity(lab : workflow_lab, line : string) : <div> workflow_lab
  lab(activity_log = lab.activity_log ++ [line])

pub fun set_search_query(owner : model, value : string) : <bridge_request_effect,div> model
  val lab = owner.lab
  val demo = lab.search_demo
  val trimmed = trim(value)
  val (next_demo, should_arm) = prepare_search_query_update(
    demo,
    value,
    search_idle_note(),
    "Typing pause armed an automatic search. If no newer input arrives, the current menu query will start through the same suspense-lite bridge.",
    "Current visible menu results already match this query.")
  if should_arm then {
    request_bridge_result("search-auto", trimmed, next_demo.auto_request_id, search_auto_delay())
    owner(lab = lab(search_demo = next_demo))
  }
  else
    owner(lab = lab(search_demo = next_demo))

fun start_search_query(owner : model, query : string) : <bridge_demo_effect,div> model
  val trimmed = trim(query)
  if trimmed == "" then
    owner(notice = "Search query is empty. Type a keyword before running the suspense-lite search demo.")
  else {
    val lab = owner.lab
    val demo = lab.search_demo
    val (next_demo, has_visible) = prepare_search_start(
      demo,
      trimmed,
      "Cold search enters a fallback while the mock server result races against the timeout budget.",
      "Refreshing search keeps the previous hit list visible until the newer query resolves or times out.")
    request_bridge_result("search", trimmed, next_demo.request_id, search_result_delay(trimmed))
    request_bridge_result("search-timeout", trimmed, next_demo.request_id, search_timeout_delay(trimmed))
    audit("Scheduled suspense-lite search for `" ++ trimmed ++ "`.")
    val next_lab = append_search_activity(lab(search_demo = next_demo), "[search] pending for `" ++ trimmed ++ "`")
    owner(lab = next_lab, notice = if has_visible then "Search is refreshing while keeping stale results visible." else "Search entered a suspense-lite fallback state.")
  }

pub fun start_search(owner : model) : <bridge_demo_effect,div> model
  start_search_query(owner, owner.lab.search_demo.query_input)

pub fun pick_search_case(owner : model, query : string) : <bridge_demo_effect,div> model
  val lab = owner.lab
  val demo = lab.search_demo
  val next_owner = owner(lab = lab(search_demo = demo(query_input = query)))
  start_search_query(next_owner, query)

pub fun resolve_search_result(owner : model, payload : string) : <bridge_demo_effect,div> maybe<model>
  match decode_bridge_result_payload(payload)
    Just(Bridge_signal(resource_tag, query, sig_id)) -> {
      if resource_tag != "bridge-search" && resource_tag != "bridge-search-timeout" && resource_tag != "bridge-search-auto" then
        Nothing
      else {
        val lab = owner.lab
        val demo = lab.search_demo
        if resource_tag == "bridge-search-auto" then
          if not(search_auto_matches(demo, query, sig_id)) then
            Just(owner)
          else if not(search_auto_should_start(demo, query)) then
            Just(owner(lab = lab(search_demo = clear_search_auto(demo))))
          else
            Just(start_search_query(owner(lab = lab(search_demo = clear_search_auto(demo))), query))
        else if not(search_request_matches(demo, query, sig_id)) then
          Just(owner)
        else {
          if resource_tag == "bridge-search-timeout" then
            match apply_search_timeout(
              demo,
              "Timeout fired before any search result became visible.",
              "Timeout fired, but stale hits stay on screen until the current response either recovers or gets replaced.")
              Nothing -> Just(owner)
              Just((next_demo, has_visible)) -> {
                audit("Search timeout fired for `" ++ query ++ "`.")
                val next_lab = append_search_activity(lab(search_demo = next_demo), "[search] timeout for `" ++ query ++ "`")
                Just(owner(lab = next_lab, notice = if has_visible then "Search timeout fired; stale results remain visible." else "Search timed out before any result became visible."))
              }
          else {
            audit("Search results resolved for `" ++ query ++ "`.")
            val (next_demo, recovered) = apply_search_result(
              demo,
              query,
              search_result_lines(query),
              "Late server results recovered after the timeout banner had already appeared.",
              search_case_summary(query))
            val next_lab = append_search_activity(lab(search_demo = next_demo), "[search] ready for `" ++ query ++ "`")
            Just(owner(lab = next_lab, notice = if recovered then "Late search results recovered after timing out." else "Search results resolved through the suspense-lite bridge."))
          }
        }
      }
    }
    Nothing -> Nothing