module demo/tests/labcases

import library/bridge
import library/route
import library/search
import demo/model
import demo/runtimeframe
import demo/seed
import demo/lab/state
import demo/lab/workflow
import demo/labpanel
import demo/tests/appharness
import demo/tests/support
import explore/react/core
import explore/react/state

pub fun lab_local_routing_test() : <div> test_result
  with with_test_browser(False, "T+120")
  val base = initial_model()(route_name = normalize_route("lab"))
  val (base_frame, _tree, _effects, _registry) = run_runtime_render(current_runtime_frame(base, Nil), run_lab_panel)
  val base_runtime_tree = runtime_frame/runtime_tree(base_frame)
  val drafted = run_runtime_action(current_runtime_frame(base, base_runtime_tree), fn(owner) {
    match handle_lab_input("lab-draft-101", "Shift traffic to backup POP.", owner)
      Just(result) -> result
      Nothing -> owner
  })
  val toggled = run_runtime_action(drafted, fn(owner) {
    match handle_lab_click("lab-toggle-101", owner)
      Just(result) -> result
      Nothing -> owner
  })
  val toggled_runtime_tree = toggled.runtime_tree
  Test_result("Workflow lab local routing", "draft=" ++ inspect_incident_draft(toggled_runtime_tree, 101) ++ ", expanded=" ++ inspect_incident_expanded(toggled_runtime_tree, 101).show, inspect_incident_draft(toggled_runtime_tree, 101) == "Shift traffic to backup POP." && inspect_incident_expanded(toggled_runtime_tree, 101))

pub fun component_action_props_test() : <div> test_result
  val search_harness = app_harness(initial_model()(route_name = normalize_route("lab-search")))
  val search_payload = button_payload_by_text(search_harness.tree, "Dialog overlay drawer")
  val search_input_channel = match find_registered_input_by_semantic(search_harness.registry, "search-query")
    Just(found) -> registered_input/id(found)
    Nothing -> ""
  val search_registered = match find_registered_click(search_harness.registry, search_payload)
    Just(found) -> registered_click/semantic_name(found) == "search-dialog-drawer"
    Nothing -> False
  val (input_search_harness, input_requests, _input_audits) = capture_bridge(fn() app_harness_input_channel(search_harness, search_input_channel, "dialog"))
  val input_search_owner : model = input_search_harness.owner
  val input_search_lab : workflow_lab = input_search_owner.lab
  val input_search_demo = input_search_lab.search_demo
  val filtered_search_harness = app_harness(input_search_owner(
    lab = input_search_lab(search_demo = input_search_demo(visible_query = "dialog"))))
  val filtered_search_payload = button_payload_by_text(filtered_search_harness.tree, "Dialog overlay drawer")
  val (search_owner, search_requests, _search_audits) = capture_bridge(fn() app_harness_click_payload(search_harness, search_payload).owner)

  val bridge_harness = app_harness(initial_model()(route_name = normalize_route("lab-bridge")))
  val bridge_payload = button_payload_by_text(bridge_harness.tree, "Replay Queue Drain")
  val bridge_registered = match find_registered_click(bridge_harness.registry, bridge_payload)
    Just(found) -> registered_click/semantic_name(found) == "bridge-queue-drain"
    Nothing -> False
  val (bridge_owner, bridge_requests, _bridge_audits) = capture_bridge(fn() app_harness_click_payload(bridge_harness, bridge_payload).owner)

  val search_started = search_owner.lab.search_demo.requested_query == "dialog" && length(search_requests) == 2
  val input_controlled =
    search_input_channel == component_listener_path("lab", "panel", Input_event, "search-query") &&
    input_search_harness.owner.lab.search_demo.query_input == "dialog" &&
    length(input_requests) == 1
  val search_identity_stable = search_payload == filtered_search_payload
  val bridge_started = bridge_owner.lab.bridge_demo.requested_case == "queue-drain" && length(bridge_requests) == 1
  val registries_clean = is-empty(search_harness.registry.warnings) && is-empty(input_search_harness.registry.warnings) && is-empty(filtered_search_harness.registry.warnings) && is-empty(bridge_harness.registry.warnings)
  Test_result(
    "Component callback props register typed actions",
    "search=" ++ search_registered.show ++ "/" ++ search_requests.length.show ++ ", input=" ++ input_controlled.show ++ "/" ++ input_requests.length.show ++ ", stable=" ++ search_identity_stable.show ++ ", bridge=" ++ bridge_registered.show ++ "/" ++ bridge_requests.length.show ++ ", clean=" ++ registries_clean.show,
    search_registered && input_controlled && search_identity_stable && bridge_registered && search_started && bridge_started && registries_clean)

pub fun workflow_sync_test() : <div> test_result
  val (next, waits, audits) = capture_workflow(fn() perform_sync(initial_model()(route_name = normalize_route("lab"))))
  val total = sum(waits)
  val lab = next.lab
  Test_result(
    "Workflow sync captures waits",
    "incidents=" ++ length(lab.incidents).show ++ ", waits=" ++ total.show ++ "ms, audits=" ++ length(audits).show ++ ", sync=" ++ lab.last_sync_label,
    length(lab.incidents) == 3 && total == 120 && length(audits) == 1 && lab.last_sync_label == "T+120")

pub fun workflow_reply_test() : <div> test_result
  val base = initial_model()(route_name = normalize_route("lab"))
  val (prepared, prepared_runtime_tree) = run_local_action(Nil, fn() {
    dispatch_incident_local_action(102, Change_incident_draft("Shift replay traffic onto the cache-safe queue."))
    base
  })
  val ((next, next_runtime_tree), waits, _audits) = capture_workflow(fn() run_local_action(prepared_runtime_tree, fn() send_reply(prepared, 102)))
  val total = sum(waits)
  val lab = next.lab
  val cleared = inspect_incident_draft(next_runtime_tree, 102) == ""
  val acked = match find(lab.incidents, fn(item) 102 == incident/id(item))
    Just(item) -> (match item.status { Status_acked -> True; _ -> False }) && item.server_note == "Shift replay traffic onto the cache-safe queue."
    Nothing -> False
  Test_result("Workflow reply clears local draft", "waits=" ++ total.show ++ "ms, drafts=" ++ length(filter(lab.incidents, fn(item) inspect_incident_draft(next_runtime_tree, incident/id(item)) != "")).show ++ ", status=" ++ lab.sync_status, cleared && acked && total == 60)

pub fun bridge_pending_test() : <div> test_result
  val (next, requests, audits) = capture_bridge_load(bridge_base_model(), "edge-auth")
  val (detail, passed) = bridge_expectation_result(next, requests, audits, bridge_expect("bridge-shell|edge-auth|1@520", 1, 1, "", "edge-auth", "pending", "idle"))
  Test_result("Bridge demo enters pending", detail, passed)

pub fun bridge_resolve_test() : <div> test_result
  val (started, _start_requests, _start_audits) = capture_bridge_load(bridge_base_model(), "edge-auth")
  val (shell_ready, detail_requests, shell_audits) = capture_bridge_shell(started, "edge-auth", 1)
  val (detail_ready, nested_requests, detail_audits) = capture_bridge_detail(shell_ready, "edge-auth", 1)
  val nested_request_count = length(nested_requests)
  val (detail, passed) = bridge_expectation_result(detail_ready, detail_requests, detail_audits, bridge_expect("bridge-detail|edge-auth|1@980", 1, 1, "edge-auth", "edge-auth", "ready", "ready"))
  Test_result(
    "Bridge demo resolves nested detail",
    detail ++ ", shell-audits=" ++ length(shell_audits).show ++ ", nested-requests=" ++ nested_request_count.show,
    passed && nested_request_count == 0 && length(shell_audits) == 1)

pub fun bridge_refresh_keeps_visible_test() : <div> test_result
  val detail_ready = bridge_ready_model("edge-auth")
  val (refreshing, requests, audits) = capture_bridge_load(detail_ready, "queue-drain")
  val (detail, passed) = bridge_expectation_result(refreshing, requests, audits, bridge_expect("bridge-shell|queue-drain|2@820", 1, 1, "edge-auth", "queue-drain", "refreshing", "ready"))
  Test_result("Bridge refresh keeps visible shell", detail, passed)

pub fun bridge_stale_shell_ignored_test() : <div> test_result
  val detail_ready = bridge_ready_model("edge-auth")
  val (refreshing, _refresh_requests, _refresh_audits) = capture_bridge_load(detail_ready, "queue-drain")
  val (ignored, stale_requests, stale_audits) = capture_bridge_shell(refreshing, "edge-auth", 1)
  val (detail, passed) = bridge_expectation_result(ignored, stale_requests, stale_audits, bridge_expect("<none>", 0, 0, "edge-auth", "queue-drain", "refreshing", "ready"))
  Test_result("Bridge ignores stale shell result", detail, passed)

pub fun bridge_stale_detail_ignored_test() : <div> test_result
  val detail_ready = bridge_ready_model("edge-auth")
  val (refreshing, _refresh_requests, _refresh_audits) = capture_bridge_load(detail_ready, "queue-drain")
  val (ignored, stale_requests, stale_audits) = capture_bridge_detail(refreshing, "edge-auth", 1)
  val (detail, passed) = bridge_expectation_result(ignored, stale_requests, stale_audits, bridge_expect("<none>", 0, 0, "edge-auth", "queue-drain", "refreshing", "ready"))
  Test_result("Bridge ignores stale detail result", detail, passed)

pub fun bridge_interleaved_old_detail_ignored_test() : <div> test_result
  val detail_ready = bridge_ready_model("edge-auth")
  val (refreshing, _refresh_requests, _refresh_audits) = capture_bridge_load(detail_ready, "queue-drain")
  val (shell_swapped, detail_requests, shell_audits) = capture_bridge_shell(refreshing, "queue-drain", 2)
  val (ignored, stale_requests, stale_audits) = capture_bridge_detail(shell_swapped, "edge-auth", 1)
  val (detail, passed) = bridge_expectation_result(ignored, stale_requests, stale_audits, bridge_expect("<none>", 0, 0, "queue-drain", "queue-drain", "ready", "pending"))
  Test_result(
    "Bridge ignores old detail after shell swap",
    "detail-request=" ++ first_text(detail_requests) ++ ", " ++ detail ++ ", shell-audits=" ++ length(shell_audits).show,
    first_text(detail_requests) == "bridge-detail|queue-drain|2@540" && length(shell_audits) == 1 && passed)
