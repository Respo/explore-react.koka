module demo/labpanel

import demo/model
import demo/lab/events
import demo/lab/view
import library/bridge
import explore/react/core
import explore/react/state

pub fun lab_panel(item : model, runtime_tree : list<state_entry>) : <div> vnode
  val (_next_item, _next_runtime_tree, panel_node, _pending_effects, _handlers) = run_lab_panel(item, runtime_tree)
  panel_node

pub fun run_lab_panel(item : model, runtime_tree : list<state_entry>) : <div> (model, list<state_entry>, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  run_stateful_component_with_tree(
    item,
    runtime_tree,
    fn(owner) component_root("lab", "panel", fn() render_lab_panel(owner, runtime_tree)))

pub fun handle_lab_click(payload : string, owner : model) : <lab_action_effect,div> maybe<model>
  route_lab_click(payload, owner)

pub fun handle_lab_input(channel : string, value : string, owner : model) : <bridge_request_effect,div> maybe<model>
  route_lab_input(channel, value, owner)
