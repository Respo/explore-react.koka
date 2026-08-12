module demo/view

import demo/dialogs
import demo/model
import demo/tests/support
import demo/layout
import library/dialog
import explore/react/core
import explore/react/state

fun append_overlay(shell_node : vnode, overlay_node : vnode) : <div> vnode
  shell_node(children = append(vnode/children(shell_node), [overlay_node]))

pub fun render_app_with_runtime(previous_item : maybe<model>, item : model, runtime_tree : list<state_entry>, results : list<test_result>) : <div> (model, list<state_entry>, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (next_model, next_runtime_tree, shell_node, shell_effects, shell_handlers) = run_root_component_with_tree(item, "app", "root", fn(owner) render_layout(owner, runtime_tree, results))
  val prepared_runtime_tree = reconcile_dialog_runtime_tree(previous_item, next_model, next_runtime_tree)
  if dialog_is_open(next_model.dialog) then {
    val (overlay_owner, next_runtime_tree2, overlay_node, overlay_effects, overlay_handlers) = run_dialog_overlay(next_model, prepared_runtime_tree)
    (overlay_owner, next_runtime_tree2, append_overlay(shell_node, overlay_node), append_scheduled_effects(shell_effects, overlay_effects), append_event_registries(shell_handlers, overlay_handlers))
  }
  else
    (next_model, prepared_runtime_tree, shell_node, shell_effects, shell_handlers)

pub fun render_app(item : model, results : list<test_result>) : <div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (next_model, _dialog_runtime_tree, tree, effects, registry) = render_app_with_runtime(Nothing, item, Nil, results)
  (next_model, tree, effects, registry)


