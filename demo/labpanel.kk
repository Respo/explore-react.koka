module demo/labpanel

import demo/model
import demo/lab/events
import demo/lab/view
import library/bridge
import explore/react/core
import explore/react/state

pub fun run_lab_panel(item : model) : <component_runtime,div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  run_stateful_component(
    item,
    fn(owner) component_root("lab", "panel", fn() render_lab_panel(owner)))

pub fun handle_lab_click(payload : string, owner : model) : <lab_action_effect,local_state_read,local_state_write,div> maybe<model>
  route_lab_click(payload, owner)

pub fun handle_lab_input(channel : string, value : string, owner : model) : <bridge_request_effect,local_state_write,div> maybe<model>
  route_lab_input(channel, value, owner)
