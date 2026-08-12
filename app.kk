module app

import boilerplate/browserapp

pub fun dispatch_click_bridge(payload : string) : _e ()
  browserapp/dispatch_click_bridge(payload)

pub fun dispatch_input_bridge(channel : string, value : string) : _e ()
  browserapp/dispatch_input_bridge(channel, value)

pub fun dispatch_route_bridge(route_name : string) : _e ()
  browserapp/dispatch_route_bridge(route_name)

pub fun boot(root_id : string) : _e ()
  browserapp/boot(root_id)
