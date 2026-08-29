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

// The app owns one global overlay surface. Keep its feature cleanup at the
// integration boundary instead of exposing component-runtime operations from
// the dialog component module.
fun reconcile_dialog_feature(previous_item : maybe<model>, item : model) : <component_runtime,div> ()
  if not(dialog_is_open(item.dialog)) then
    reset_feature(group = "overlays", key = "dialog")
  else
    match previous_item
      Just(previous) ->
        if previous.dialog.kind.show_kind == item.dialog.kind.show_kind then ()
        else reset_feature(group = "overlays", key = "dialog")
      Nothing -> ()

pub fun render_app_with_runtime(previous_item : maybe<model>, item : model, results : list<test_result>) : <component_runtime,div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  reconcile_dialog_feature(previous_item, item)
  run_component(
    item,
    group = "app",
    key = "root",
    render = fn(owner) {
      val shell_node = render_layout(owner, results)
      if dialog_is_open(owner.dialog) then
        append_overlay(shell_node, dialog_overlay(owner))
      else
        shell_node
    })

pub fun render_app(item : model, results : list<test_result>) : <div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (rendered, _runtime_tree) = with_component_runtime(Nil, fn() render_app_with_runtime(Nothing, item, results))
  rendered
