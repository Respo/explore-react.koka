module demo/tests/labcases

import library/bridge
import library/route
import demo/model
import demo/runtimeowner
import demo/runtimebridge
import demo/seed
import demo/lab/state
import demo/lab/workflow
import demo/labpanel
import demo/tests/support
import explore/react/state

pub fun lab_local_routing_test() : <div> test_result
  with with_test_browser(False, "T+120")
  val base = initial_model()(route_name = normalize_route("lab"))
  val (_base_owner, base_runtime_tree, _tree, _effects, _registry) = run_lab_panel(base, Nil)
  val drafted_with_tree = match handle_lab_input("lab-draft-101", "Shift traffic to backup POP.", runtimeowner/attach_runtime_tree(base, base_runtime_tree))
    Just(result) -> result
    Nothing -> runtimeowner/attach_runtime_tree(base, base_runtime_tree)
  val (drafted, drafted_runtime_tree) = runtimeowner/detach_runtime_tree(drafted_with_tree)
  val toggled_with_tree = match handle_lab_click("lab-toggle-101", runtimeowner/attach_runtime_tree(drafted, drafted_runtime_tree))
    Just(result) -> result
    Nothing -> runtimeowner/attach_runtime_tree(drafted, drafted_runtime_tree)
  val (_toggled, toggled_runtime_tree) = runtimeowner/detach_runtime_tree(toggled_with_tree)
  Test_result("Workflow lab local routing", "draft=" ++ lab_incident_draft(toggled_runtime_tree, 101) ++ ", expanded=" ++ lab_incident_expanded(toggled_runtime_tree, 101).show, lab_incident_draft(toggled_runtime_tree, 101) == "Shift traffic to backup POP." && lab_incident_expanded(toggled_runtime_tree, 101))

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
  val prepared_with_tree = commit_lab_tree(runtimeowner/attach_runtime_tree(base, Nil), fn() set_local_lab_draft(base, 102, "Shift replay traffic onto the cache-safe queue."))
  val (next_with_tree, waits, _audits) = capture_workflow(fn() send_reply(prepared_with_tree, 102))
  val (next, next_runtime_tree) = runtimeowner/detach_runtime_tree(next_with_tree)
  val total = sum(waits)
  val lab = next.lab
  val cleared = lab_incident_draft(next_runtime_tree, 102) == ""
  val acked = match find(lab.incidents, fn(item) 102 == incident/id(item))
    Just(item) -> (match item.status { Status_acked -> True; _ -> False }) && item.server_note == "Shift replay traffic onto the cache-safe queue."
    Nothing -> False
  Test_result("Workflow reply clears local draft", "waits=" ++ total.show ++ "ms, drafts=" ++ length(filter(lab.incidents, fn(item) lab_incident_draft(next_runtime_tree, incident/id(item)) != "")).show ++ ", status=" ++ lab.sync_status, cleared && acked && total == 60)

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