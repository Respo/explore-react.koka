module demo/tests/support

import demo/dialogs
import demo/lab/state
import demo/labpanel
import demo/model
import demo/runtimebridge
import demo/seed
import demo/todo/state
import demo/todopanel
import library/bridge
import library/route
import library/search
import explore/react/core
import explore/react/state

pub struct test_result(name : string, detail : string, passed : bool)

pub struct bridge_expectation
  first_request : string
  request_count : int
  audit_count : int
  visible_case : string
  requested_case : string
  shell_status : string
  detail_status : string

pub fun maybe_text(target : maybe<string>) : string
  match target
    Just(name) -> name
    Nothing -> "<none>"

pub fun first_text(items : list<string>) : string
  match items
    Cons(first, _rest) -> first
    Nil -> "<none>"

pub fun with_test_browser_host<a,e>(confirm_result : bool, stamp : string, action : () -> <browser_host|e> a) : e a
  with handler
    fun confirm_action(_message) confirm_result
    fun audit(_message) ()
    val current_operator = "test-operator"
    fun fetch_lab_snapshot() mock_lab_snapshot()
    fun now_label() stamp
    fun post_lab_reply(_incident_id, message) message
    fun wait_ms(_delay) ()
  action()

pub fun with_test_browser<a,e>(confirm_result : bool, stamp : string, action : () -> <browser_host,request_bridge_resource|e> a) : e a
  with fun request_bridge_resource(_payload, _delay) ()
  with_test_browser_host(confirm_result, stamp, action)

pub fun capture_waits(action : () -> <browser_host|e> string) : e (string, list<int>)
  var waits := Nil
  with return(result) (result, waits)
  with handler
    fun confirm_action(_message) False
    fun audit(_message) ()
    val current_operator = "test-operator"
    fun fetch_lab_snapshot() mock_lab_snapshot()
    fun now_label() "T+0"
    fun post_lab_reply(_incident_id, message) message
    fun wait_ms(delay) waits := Cons(delay, waits)
  action()

pub fun capture_workflow(action : () -> <browser_host|e> model) : e (model, list<int>, list<string>)
  var waits := Nil
  var audits := Nil
  with return(result) (result, waits, audits)
  with handler
    fun confirm_action(_message) False
    fun audit(message) audits := Cons(message, audits)
    val current_operator = "test-operator"
    fun wait_ms(delay) waits := Cons(delay, waits)
    fun fetch_lab_snapshot() mock_lab_snapshot()
    fun post_lab_reply(incident_id, message) mock_lab_reply(incident_id, message)
    fun now_label() "T+120"
  action()

pub fun capture_audits(action : () -> <browser_host|e> model) : e (model, list<string>)
  var audits := Nil
  with return(result) (result, audits)
  with handler
    fun confirm_action(_message) False
    fun audit(message) audits := Cons(message, audits)
    val current_operator = "test-operator"
    fun wait_ms(_delay) ()
    fun fetch_lab_snapshot() mock_lab_snapshot()
    fun post_lab_reply(_incident_id, message) message
    fun now_label() "T+0"
  action()

pub fun capture_bridge(action : () -> <browser_host,request_bridge_resource|e> model) : e (model, list<string>, list<string>)
  var requests := Nil
  var audits := Nil
  with return(result) (result, requests, audits)
  with handler
    fun confirm_action(_message) False
    fun audit(message) audits := Cons(message, audits)
    val current_operator = "test-operator"
    fun wait_ms(_delay) ()
    fun fetch_lab_snapshot() mock_lab_snapshot()
    fun post_lab_reply(incident_id, message) mock_lab_reply(incident_id, message)
    fun now_label() "T+120"
  with fun request_bridge_resource(payload, delay) requests := Cons(payload ++ "@" ++ delay.show, requests)
  action()

pub fun bridge_base_model() : model
  initial_model()(route_name = normalize_route("lab"))

pub fun bridge_click(owner : model, payload : string) : <browser_host,request_bridge_resource,div> model
  match handle_lab_click(payload, owner)
    Just(result) -> result
    Nothing -> owner

pub fun capture_bridge_click(owner : model, payload : string) : <div> (model, list<string>, list<string>)
  capture_bridge(fn() bridge_click(owner, payload))

pub fun capture_bridge_load(owner : model, case_name : string) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, bridge_load_payload(case_name))

pub fun capture_bridge_shell(owner : model, case_name : string, request_id : int) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, bridge_result_payload("shell", case_name, request_id))

pub fun capture_bridge_detail(owner : model, case_name : string, request_id : int) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, bridge_result_payload("detail", case_name, request_id))

pub fun bridge_ready_model(case_name : string) : <div> model
  val (started, _start_requests, _start_audits) = capture_bridge_load(bridge_base_model(), case_name)
  val (shell_ready, _shell_requests, _shell_audits) = capture_bridge_shell(started, case_name, 1)
  val (detail_ready, _detail_requests, _detail_audits) = capture_bridge_detail(shell_ready, case_name, 1)
  detail_ready

pub fun search_base_model() : model
  initial_model()(route_name = normalize_route("lab"))

pub fun capture_search_input(owner : model, value : string) : <div> (model, list<string>, list<string>)
  capture_bridge(fn() {
    match handle_lab_input(search_query_channel(), value, owner)
      Just(result) -> result
      Nothing -> owner
  })

pub fun search_input(owner : model, value : string) : <div> model
  val (next, _requests, _audits) = capture_search_input(owner, value)
  next

pub fun capture_search_submit(owner : model) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, search_submit_payload())

pub fun capture_search_pick(owner : model, query : string) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, search_pick_payload(query))

pub fun capture_search_result(owner : model, query : string, request_id : int) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, bridge_result_payload("search", query, request_id))

pub fun capture_search_timeout(owner : model, query : string, request_id : int) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, bridge_result_payload("search-timeout", query, request_id))

pub fun capture_search_auto(owner : model, query : string, auto_request_id : int) : <div> (model, list<string>, list<string>)
  capture_bridge_click(owner, bridge_result_payload("search-auto", query, auto_request_id))

pub fun dialog_base_model() : model
  initial_model()(route_name = normalize_route("effects"))

pub fun dialog_click(owner : model, payload : string) : <browser_host,div> model
  match handle_dialog_click(payload, owner)
    Just(result) -> result
    Nothing -> owner

pub fun capture_dialog_click(owner : model, payload : string) : <div> (model, list<string>)
  capture_audits(fn() dialog_click(owner, payload))

pub fun bridge_expect(
  first_request : string,
  request_count : int,
  audit_count : int,
  visible_case : string,
  requested_case : string,
  shell_status : string,
  detail_status : string
) : bridge_expectation
  Bridge_expectation(first_request, request_count, audit_count, visible_case, requested_case, shell_status, detail_status)

pub fun bridge_expectation_result(owner : model, requests : list<string>, audits : list<string>, expected : bridge_expectation) : <div> (string, bool)
  val demo = owner.lab.bridge_demo
  val request_label = first_text(requests)
  val request_count = length(requests)
  val audit_count = length(audits)
  val detail =
    "request=" ++ request_label ++
    ", requests=" ++ request_count.show ++
    ", audits=" ++ audit_count.show ++
    ", visible=" ++ demo.visible_case ++
    ", requested=" ++ demo.requested_case ++
    ", shell=" ++ demo.shell_status ++
    ", detail=" ++ demo.detail_status
  val passed =
    request_label == bridge_expectation/first_request(expected) &&
    request_count == bridge_expectation/request_count(expected) &&
    audit_count == bridge_expectation/audit_count(expected) &&
    demo.visible_case == bridge_expectation/visible_case(expected) &&
    demo.requested_case == bridge_expectation/requested_case(expected) &&
    demo.shell_status == bridge_expectation/shell_status(expected) &&
    demo.detail_status == bridge_expectation/detail_status(expected)
  (detail, passed)

fun attrs_have_value(attrs : list<attr>, target_name : string, target_value : string) : <div> bool
  any(attrs, fn(item) attr/name(item) == target_name && attr/value(item) == target_value)

fun children_have_attr_value(nodes : list<vnode>, target_name : string, target_value : string) : <div> bool
  any(nodes, fn(node) vnode_has_attr_value(node, target_name, target_value))

pub fun vnode_has_attr_value(node : vnode, target_name : string, target_value : string) : <div> bool
  attrs_have_value(vnode/attrs(node), target_name, target_value) || children_have_attr_value(vnode/children(node), target_name, target_value)

pub fun keyed_button_payload(tree : vnode, key_name : string, label : string) : <div> string
  match vnode_find_key(tree, key_name)
    Just(branch) -> match vnode_find_text(branch, label)
      Just(node) -> vnode_click_payload(node)
      Nothing -> ""
    Nothing -> ""

pub fun keyed_input_channel(tree : vnode, key_name : string, effect_marker : string) : <div> string
  match vnode_find_key(tree, key_name)
    Just(branch) -> match vnode_find_attr_value(branch, "data-k-effect", effect_marker)
      Just(node) -> vnode_input_channel(node)
      Nothing -> ""
    Nothing -> ""

// --- Component harness ---
// Wraps one rendered frame (model + vnode + effects + registry) so tests can fire
// events and re-render in a composable way without manually threading the 4-tuple.

pub struct component_harness
  owner : model
  tree : vnode
  effects : list<scheduled_effect>
  registry : event_registry<model, browser_event_effect>
  runtime_tree : list<state_entry>

pub fun todo_harness_render(owner : model, runtime_tree : list<state_entry>) : <div> component_harness
  val (next_model, next_runtime_tree, tree, effects, registry) = run_todo_panel(owner, runtime_tree)
  Component_harness(next_model, tree, effects, registry, next_runtime_tree)

pub fun todo_harness(owner : model) : <div> component_harness
  todo_harness_render(owner, Nil)

// Fire a locally-registered click by semantic name; re-render via render_fn.
// The caller must have browser_event_effect in scope (same as capture_bridge tests).
pub fun harness_fire_named_click(
  h : component_harness,
  semantic_name : string,
  render_fn : (model, list<state_entry>) -> <div> component_harness
) : <browser_event_effect,div> component_harness
  match find_registered_click_by_semantic(h.registry, semantic_name)
    Nothing -> h
    Just(found) -> {
      val (next_owner, next_runtime_tree) = runtimebridge/run_with_runtime_tree(registered_click/id(found), h.owner, h.runtime_tree, fn(current_owner) run_registered_click(found, current_owner))
      render_fn(next_owner, next_runtime_tree)
    }

// Fire a locally-registered input by semantic name; re-render via render_fn.
pub fun harness_fire_named_input(
  h : component_harness,
  semantic_name : string,
  value : string,
  render_fn : (model, list<state_entry>) -> <div> component_harness
) : <div> component_harness
  match find_registered_input_by_semantic(h.registry, semantic_name)
    Nothing -> h
    Just(found) -> {
      val (next_owner, next_runtime_tree) = runtimebridge/run_with_runtime_tree(registered_input/id(found), h.owner, h.runtime_tree, fn(current_owner) run_registered_input(found, value, current_owner))
      render_fn(next_owner, next_runtime_tree)
    }

pub fun harness_fire_input_channel(
  h : component_harness,
  channel : string,
  value : string,
  render_fn : (model, list<state_entry>) -> <div> component_harness
) : <div> component_harness
  match find_registered_input(h.registry, channel)
    Nothing -> h
    Just(found) -> {
      val (next_owner, next_runtime_tree) = runtimebridge/run_with_runtime_tree(channel, h.owner, h.runtime_tree, fn(current_owner) run_registered_input(found, value, current_owner))
      render_fn(next_owner, next_runtime_tree)
    }

// Fire a click using the exact payload string (the value in data-k-click).
// Looks in the registry first; no-ops if not found (global dispatch is out of scope here).
pub fun harness_fire_click_payload(
  h : component_harness,
  payload : string,
  render_fn : (model, list<state_entry>) -> <div> component_harness
) : <browser_event_effect,div> component_harness
  match find_registered_click(h.registry, payload)
    Just(found) -> {
      val (next_owner, next_runtime_tree) = runtimebridge/run_with_runtime_tree(payload, h.owner, h.runtime_tree, fn(current_owner) run_registered_click(found, current_owner))
      render_fn(next_owner, next_runtime_tree)
    }
    Nothing -> h

// Fire a todo click payload the same way the browser does: look up in the local registry.
pub fun todo_harness_click_payload(
  h : component_harness,
  payload : string
) : <browser_event_effect,div> component_harness
  match find_registered_click(h.registry, payload)
    Just(found) -> {
      val (next_owner, next_runtime_tree) = runtimebridge/run_with_runtime_tree(payload, h.owner, h.runtime_tree, fn(current_owner) run_registered_click(found, current_owner))
      todo_harness_render(next_owner, next_runtime_tree)
    }
    Nothing -> h