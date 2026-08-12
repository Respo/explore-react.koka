module demo/tests/appharness

import demo/controller
import demo/model
import demo/runtimebridge
import demo/runtimeframe
import demo/view
import demo/tests/support
import library/bridge
import explore/react/core
import explore/react/state

fun app_harness_render(previous_owner : maybe<model>, frame : runtime_frame) : <div> component_harness
  val (next_model, next_runtime_tree, tree, effects, registry) = render_app_with_runtime(previous_owner, runtime_frame/owner(frame), runtime_frame/runtime_tree(frame), Nil)
  Component_harness(next_model, tree, effects, registry, next_runtime_tree)

pub fun app_harness(owner : model) : <div> component_harness
  app_harness_render(Nothing, current_runtime_frame(owner, Nil))

pub fun app_harness_click_payload(
  h : component_harness,
  payload : string
) : <browser_event_effect,div> component_harness
  match find_registered_click(h.registry, payload)
    Just(found) -> app_harness_render(Just(h.owner), run_runtime_path(payload, current_runtime_frame(h.owner, h.runtime_tree), fn(current_owner) run_registered_click(found, current_owner)))
    Nothing -> app_harness_render(Just(h.owner), map_runtime_owner(current_runtime_frame(h.owner, h.runtime_tree), fn(owner) controller/dispatch_click(payload, owner)))

pub fun app_harness_input_channel(
  h : component_harness,
  channel : string,
  value : string
) : <bridge_request_effect,div> component_harness
  match find_registered_input(h.registry, channel)
    Just(found) -> app_harness_render(Just(h.owner), run_runtime_path(channel, current_runtime_frame(h.owner, h.runtime_tree), fn(current_owner) run_registered_input(found, value, current_owner)))
    Nothing -> app_harness_render(Just(h.owner), map_runtime_owner(current_runtime_frame(h.owner, h.runtime_tree), fn(owner) controller/dispatch_input(channel, value, owner)))

pub fun button_payload_by_text(tree : vnode, label : string) : <div> string
  match vnode_find_text(tree, label)
    Just(node) -> vnode_click_payload(node)
    Nothing -> ""

pub fun input_channel_by_effect_marker(tree : vnode, effect_marker : string) : <div> string
  match vnode_find_attr_value(tree, "data-k-effect", effect_marker)
    Just(node) -> vnode_input_channel(node)
    Nothing -> ""