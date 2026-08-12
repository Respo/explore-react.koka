module demo/tests

import demo/tests/support
import demo/tests/basics
import demo/tests/dialogcases
import demo/tests/searchcases
import demo/tests/statecases
import demo/tests/todocases
import demo/tests/labcases

pub fun demo_test_results() : <div> list<test_result>
  [
    component_render_test(),
    confirm_decline_test(),
    confirm_accept_test(),
    ambient_filter_test(),
    registered_input_handler_test(),
    registered_click_handler_test(),
    timer_simulation_test(),
    route_subroute_normalization_test(),
    route_bar_click_is_local_test(),
    state_tree_test(),
    generic_state_codec_test(),
    auto_hook_scope_test(),
    listener_registry_guard_test(),
    vnode_click_payload_matches_route_test(),
    harness_cancel_edit_test(),
    harness_draft_input_test(),
    harness_multi_step_test(),
    lab_local_routing_test(),
    add_task_focus_test(),
    start_edit_focus_test(),
    todo_edit_local_state_test(),
    todo_edit_diff_test(),
    workflow_sync_test(),
    workflow_reply_test(),
    bridge_pending_test(),
    bridge_resolve_test(),
    bridge_refresh_keeps_visible_test(),
    bridge_stale_shell_ignored_test(),
    bridge_stale_detail_ignored_test(),
    bridge_interleaved_old_detail_ignored_test(),
    dialog_alert_open_test(),
    dialog_prompt_validation_test(),
    dialog_prompt_submit_test(),
    dialog_prompt_focus_effect_test(),
    dialog_overlay_uses_runtime_tree_test(),
    dialog_drawer_action_test(),
    search_auto_timer_armed_test(),
    search_auto_timer_starts_pending_test(),
    search_stale_auto_ignored_test(),
    search_pending_test(),
    search_resolve_before_timeout_test(),
    search_result_keeps_newer_input_test(),
    search_clear_input_resets_catalog_test(),
    search_cleared_query_ignores_late_result_test(),
    search_timeout_then_recover_test(),
    search_refresh_keeps_visible_test(),
    search_stale_timeout_ignored_test(),
    search_stale_result_ignored_test(),
    search_refresh_timeout_stale_visible_test(),
    search_refresh_timeout_then_recover_test(),
    search_auto_cancelled_by_submit_test(),
    search_pick_starts_pending_test(),
  ]
