module demo/seed

import library/bridge
import library/dialog
import library/search
import demo/model

pub fun mock_lab_snapshot() : lab_snapshot
  Lab_snapshot(
    [
      Incident(101, "Edge cache serving stale auth bundle", Severity_p1, Status_firing, "Login JS bundle is 17 minutes behind origin in two POPs.", "Origin checksum mismatch observed on 4 probes.", "mock-edge-bot"),
      Incident(102, "Worker queue saturation", Severity_p2, Status_investigating, "Batch replay queue is at 86% depth after the latest deploy.", "Autoscaler added one node but backlog is still trending up.", "ops-sim"),
      Incident(103, "Image thumbnail cold start", Severity_p3, Status_acked, "New region takes 1.3s to warm the thumbnail worker.", "Tracked for the next runtime image cut.", "ops-sim"),
    ],
    "Mock server returned 3 incidents for the workflow lab.")

pub fun mock_lab_reply(incident_id : int, message : string) : string
  "Mock server accepted reply for #" ++ incident_id.show ++ ": " ++ message

fun initial_lab() : workflow_lab
  Workflow_lab(
    mock_lab_snapshot().incidents,
    ["[boot] Seeded workflow lab with a deterministic snapshot."],
    "seeded",
    "boot",
    initial_bridge_demo(default_bridge_case_name()),
    initial_search_demo(default_search_query(), "Type a query, pause to auto-search the menu catalog, keep stale results visible during refresh, and let timeout race against the mocked server response."))

pub fun initial_model() : model
  Model(
    [
      Task(1, "Map React-like updates onto a Koka store", True),
      Task(2, "Keep diff + patch inside Koka", False),
      Task(3, "Use algebraic effects for destructive flows", False),
    ],
    "",
    4,
    "all",
    "Ready: Koka owns components, state, and diff/patch.",
    "overview",
    Nil,
    initial_lab(),
    initial_dialog_demo("No overlay interaction yet."))