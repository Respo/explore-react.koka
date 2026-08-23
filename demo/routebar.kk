module demo/routebar

import demo/model
import library/route
import explore/react/core
import explore/react/state

fun route_button(label : string, route_name : string, active : bool) : app_view vnode
  val class_name = if active then "button route-tab route-tab-active" else "button route-tab"
  button(label, class = class_name, click = on_action_click("nav-" ++ route_name, action = Navigate(route_name), dispatch = dispatch_route_action))

fun lab_subroutes(active_route : string) : app_view vnode
  div([
    route_button("Board", "lab-board", active_route == "lab-board"),
    route_button("Search", "lab-search", active_route == "lab-search"),
    route_button("Bridge", "lab-bridge", active_route == "lab-bridge"),
  ], class = "route-bar route-sub-bar")

fun effects_subroutes(active_route : string) : app_view vnode
  div([
    route_button("Core", "effects-core", active_route == "effects-core"),
    route_button("Dialogs", "effects-dialogs", active_route == "effects-dialogs"),
    route_button("Workflow", "effects-workflow", active_route == "effects-workflow"),
    route_button("State", "effects-state", active_route == "effects-state"),
    route_button("Timer", "effects-timer", active_route == "effects-timer"),
  ], class = "route-bar route-sub-bar")

pub fun route_bar(item : model) : app_view vnode
  val active_route = item.route_name
  val active_section = route_section(active_route)
  val secondary_bar =
    if active_section == "lab" then lab_subroutes(active_route)
    else if active_section == "effects" then effects_subroutes(active_route)
    else div(Nil, class = "route-sub-bar route-sub-bar-empty")
  nav([
    div([
      route_button("Overview", "overview", active_section == "overview"),
      route_button("Todo", "todo", active_section == "todo"),
      route_button("Lab", "lab", active_section == "lab"),
      route_button("Effects", "effects", active_section == "effects"),
      route_button("Checks", "checks", active_section == "checks"),
    ], class = "route-bar"),
    secondary_bar,
  ], key = "route-bar", class = "panel route-panel")
