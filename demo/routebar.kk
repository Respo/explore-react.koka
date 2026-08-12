module demo/routebar

import demo/model
import library/route
import explore/react/core
import explore/react/state

alias route_bar_effect = <hook_scope,listener_registry<model,browser_event_effect>,div>

fun route_button(label : string, route_name : string, active : bool) : route_bar_effect vnode
  val class_name = if active then "button route-tab route-tab-active" else "button route-tab"
  button(props(class = class_name), on(click = on_local_click("nav-" ++ route_name, fn(owner : model) owner(route_name = normalize_route(route_name)))), label)

fun lab_subroutes(active_route : string) : route_bar_effect vnode
  div(props(class = "route-bar route-sub-bar"), [
    route_button("Board", "lab-board", active_route == "lab-board"),
    route_button("Search", "lab-search", active_route == "lab-search"),
    route_button("Bridge", "lab-bridge", active_route == "lab-bridge"),
  ])

fun effects_subroutes(active_route : string) : route_bar_effect vnode
  div(props(class = "route-bar route-sub-bar"), [
    route_button("Core", "effects-core", active_route == "effects-core"),
    route_button("Dialogs", "effects-dialogs", active_route == "effects-dialogs"),
    route_button("Workflow", "effects-workflow", active_route == "effects-workflow"),
    route_button("State", "effects-state", active_route == "effects-state"),
    route_button("Timer", "effects-timer", active_route == "effects-timer"),
  ])

pub fun route_bar(item : model) : route_bar_effect vnode
  val active_route = item.route_name
  val active_section = route_section(active_route)
  val secondary_bar =
    if active_section == "lab" then lab_subroutes(active_route)
    else if active_section == "effects" then effects_subroutes(active_route)
    else div(props(class = "route-sub-bar route-sub-bar-empty"), Nil)
  nav_key("route-bar", props(class = "panel route-panel"), [
    div(props(class = "route-bar"), [
      route_button("Overview", "overview", active_section == "overview"),
      route_button("Todo", "todo", active_section == "todo"),
      route_button("Lab", "lab", active_section == "lab"),
      route_button("Effects", "effects", active_section == "effects"),
      route_button("Checks", "checks", active_section == "checks"),
    ]),
    secondary_bar,
  ])
