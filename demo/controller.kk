module demo/controller

import demo/dialogs
import demo/labpanel
import demo/model
import library/bridge
import library/maybe

fun resolve_click(payload : string, item : model) : <browser_event_effect,div> maybe<model>
  handle_lab_click(payload, item).or-else {
    handle_dialog_click(payload, item).or-else {
      handle_route_click(payload, item)
    }
  }

pub fun dispatch_click(payload : string, item : model) : <browser_event_effect,div> model
  resolve_click(payload, item).unwrap-or-else {
    reduce_click(payload, item)
  }

fun resolve_input(channel : string, value : string, item : model) : <bridge_request_effect,div> maybe<model>
  handle_lab_input(channel, value, item)

pub fun dispatch_input(channel : string, value : string, item : model) : <bridge_request_effect,div> model
  resolve_input(channel, value, item).unwrap-or-else {
    reduce_input(channel, value, item)
  }