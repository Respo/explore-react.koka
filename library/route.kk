module library/route

pub type route_action
  Navigate(route_name : string)

pub fun normalize_route(route_name : string) : string
  if route_name == "todo" then "todo"
  else if route_name == "lab" || route_name == "lab-board" then "lab-board"
  else if route_name == "lab-search" then "lab-search"
  else if route_name == "lab-bridge" then "lab-bridge"
  else if route_name == "effects" || route_name == "effects-core" then "effects-core"
  else if route_name == "effects-dialogs" then "effects-dialogs"
  else if route_name == "effects-workflow" then "effects-workflow"
  else if route_name == "effects-state" then "effects-state"
  else if route_name == "effects-timer" then "effects-timer"
  else if route_name == "checks" then "checks"
  else "overview"

pub fun route_section(route_name : string) : string
  if route_name == "todo" then "todo"
  else if route_name == "lab-board" || route_name == "lab-search" || route_name == "lab-bridge" then "lab"
  else if route_name == "effects-core" || route_name == "effects-dialogs" || route_name == "effects-workflow" || route_name == "effects-state" || route_name == "effects-timer" then "effects"
  else if route_name == "checks" then "checks"
  else "overview"

pub fun route_is_lab(route_name : string) : bool
  route_section(route_name) == "lab"

pub fun route_is_effects(route_name : string) : bool
  route_section(route_name) == "effects"

pub fun route_action_payload(action : route_action) : string
  match action
    Navigate(route_name) -> "route-" ++ route_name

pub fun route_action_target(action : route_action) : string
  match action
    Navigate(route_name) -> route_name

pub fun decode_route_action(payload : string) : <div> maybe<route_action>
  if payload == route_action_payload(Navigate("overview")) then Just(Navigate("overview"))
  else if payload == route_action_payload(Navigate("todo")) then Just(Navigate("todo"))
  else if payload == route_action_payload(Navigate("lab")) then Just(Navigate("lab"))
  else if payload == route_action_payload(Navigate("lab-board")) then Just(Navigate("lab-board"))
  else if payload == route_action_payload(Navigate("lab-search")) then Just(Navigate("lab-search"))
  else if payload == route_action_payload(Navigate("lab-bridge")) then Just(Navigate("lab-bridge"))
  else if payload == route_action_payload(Navigate("effects")) then Just(Navigate("effects"))
  else if payload == route_action_payload(Navigate("effects-core")) then Just(Navigate("effects-core"))
  else if payload == route_action_payload(Navigate("effects-dialogs")) then Just(Navigate("effects-dialogs"))
  else if payload == route_action_payload(Navigate("effects-workflow")) then Just(Navigate("effects-workflow"))
  else if payload == route_action_payload(Navigate("effects-state")) then Just(Navigate("effects-state"))
  else if payload == route_action_payload(Navigate("effects-timer")) then Just(Navigate("effects-timer"))
  else if payload == route_action_payload(Navigate("checks")) then Just(Navigate("checks"))
  else Nothing

pub fun route_click_target(payload : string) : <div> maybe<string>
  decode_route_action(payload).map(fn(action) normalize_route(route_action_target(action)))