module demo/layout

import demo/model
import demo/tests/support
import demo/routebar
import demo/todo/view
import demo/todo/viewmodel
import demo/lab/view
import demo/effectspanel
import demo/testspanel
import library/route
import explore/react/core

fun intro_panel(item : model) : <div> vnode
  header([
    div([
      h1("explore-react core + dense debug demo", class = "page-title"),
      span("route: #" ++ item.route_name, class = "route-indicator"),
    ], class = "intro-top"),
    p("`explore/react/*` holds VDOM helpers; `demo/*` now exposes finer subroutes so search, bridge, dialogs, workflow, and timing demos are easier to inspect in isolation.", class = "section-note"),
  ], class = "panel intro-panel")

fun wrap_single_stage(node : vnode) : vnode
  div([node], class = "single-stage")

fun overview_stage(item : model, results : list<test_result>) : app_view vnode
  div([
    div([
      todo_panel(todo_panel_state_of(item)),
    ], class = "overview-main"),
    aside([
      tests_panel(results),
    ], class = "overview-side"),
    div([
      lab_panel(item),
    ], class = "overview-wide"),
    div([
      effects_panel(item, results = results),
    ], class = "overview-wide"),
  ], class = "overview-grid")

fun route_stage(item : model, results : list<test_result>) : app_view vnode
  if item.route_name == "todo" then
    wrap_single_stage(todo_panel(todo_panel_state_of(item)))
  else if route_is_lab(item.route_name) then
    wrap_single_stage(lab_panel(item))
  else if route_is_effects(item.route_name) then
    wrap_single_stage(effects_panel(item, results = results))
  else if item.route_name == "checks" then
    wrap_single_stage(tests_panel(results))
  else
    overview_stage(item, results)

pub fun render_layout(item : model, results : list<test_result>) : app_view vnode
  section([
    intro_panel(item),
    route_bar(item),
    route_stage(item, results),
  ], key = "app", class = "shell app-shell")
