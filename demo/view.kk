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

pub fun render_app_with_runtime(previous_item : maybe<model>, item : model, results : list<test_result>) : <component_runtime,div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (next_model, shell_node, shell_effects, shell_handlers) = render_layout(item, results)
  reconcile_dialog_runtime(previous_item, next_model)
  if dialog_is_open(next_model.dialog) then {
    val (overlay_owner, overlay_node, overlay_effects, overlay_handlers) = run_dialog_overlay(next_model)
    (overlay_owner, append_overlay(shell_node, overlay_node), append_scheduled_effects(shell_effects, overlay_effects), append_event_registries(shell_handlers, overlay_handlers))
  }
  else
    (next_model, shell_node, shell_effects, shell_handlers)

pub fun render_app(item : model, results : list<test_result>) : <div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (rendered, _runtime_tree) = with_component_runtime(Nil, fn() render_app_with_runtime(Nothing, item, results))
  rendered
