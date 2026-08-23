module demo/layout

import demo/model
import demo/tests/support
import demo/routebar
import demo/todopanel
import demo/labpanel
import demo/effectspanel
import demo/testspanel
import library/route
import explore/react/core
import explore/react/state

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

fun overview_stage(item : model, results : list<test_result>) : <component_runtime,div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (todo_item, todo_node, todo_effects, todo_handlers) = run_todo_panel(item)
  val (lab_item, lab_node, lab_effects, lab_handlers) = run_lab_panel(todo_item)
  val (effects_item, effects_node, effects, handlers) = run_effects_panel(lab_item, results)
  (effects_item, div([
    div([
      todo_node,
    ], class = "overview-main"),
    aside([
      tests_panel(results),
    ], class = "overview-side"),
    div([
      lab_node,
    ], class = "overview-wide"),
    div([
      effects_node,
    ], class = "overview-wide"),
  ], class = "overview-grid"), append_scheduled_effects(append_scheduled_effects(todo_effects, lab_effects), effects), append_event_registries(append_event_registries(todo_handlers, lab_handlers), handlers))

fun route_stage(item : model, results : list<test_result>) : <component_runtime,div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  if item.route_name == "todo" then
    map_component_run(run_todo_panel(item), fn(_next_item, todo_node) wrap_single_stage(todo_node))
  else if route_is_lab(item.route_name) then {
    val (next_item, lab_node, effects, handlers) = run_lab_panel(item)
    (next_item, wrap_single_stage(lab_node), effects, handlers)
  }
  else if route_is_effects(item.route_name) then {
    val (next_item, effects_node, effects, handlers) = run_effects_panel(item, results)
    (next_item, wrap_single_stage(effects_node), effects, handlers)
  }
  else if item.route_name == "checks" then
    (item, wrap_single_stage(tests_panel(results)), Nil, empty_event_registry())
  else
    overview_stage(item, results)

pub fun render_layout(item : model, results : list<test_result>) : <component_runtime,div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (stage_owner, current_stage, stage_effects, stage_handlers) = route_stage(item, results)
  val (next_owner, shell_node, shell_effects, shell_handlers) = run_stateful_component(
    stage_owner,
    fn(owner) component_root("app", "root", fn() section([
      intro_panel(owner),
      route_bar(owner),
      current_stage,
    ], key = "app", class = "shell app-shell")))
  (next_owner, shell_node, append_scheduled_effects(stage_effects, shell_effects), append_event_registries(shell_handlers, stage_handlers))
