module app

import boilerplate/browserapp

pub fun dispatch_click_bridge(payload : string) : _e ()
  browserapp/dispatch_click_bridge(payload)

pub fun dispatch_input_bridge(channel : string, value : string) : _e ()
  browserapp/dispatch_input_bridge(channel, value)

pub fun dispatch_route_bridge(route_name : string) : _e ()
  browserapp/dispatch_route_bridge(route_name)

pub fun export_state_snapshot_bridge() : _e string
  browserapp/export_state_snapshot_bridge()

pub fun dispose_runtime_bridge() : _e ()
  browserapp/dispose_runtime_bridge()

pub fun boot_with_snapshot(root_id : string, snapshot : string) : _e ()
  browserapp/boot_with_snapshot(root_id, snapshot)

pub fun boot(root_id : string) : _e ()
  browserapp/boot(root_id)
