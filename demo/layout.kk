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
  header(props(class = "panel intro-panel"), [
    div(props(class = "intro-top"), [
      h1(props(class = "page-title"), "explore-react core + dense debug demo"),
      span(props(class = "route-indicator"), "route: #" ++ item.route_name),
    ]),
    p(props(class = "section-note"), "`explore/react/*` holds VDOM helpers; `demo/*` now exposes finer subroutes so search, bridge, dialogs, workflow, and timing demos are easier to inspect in isolation."),
  ])

fun wrap_single_stage(node : vnode) : vnode
  div(props(class = "single-stage"), [node])

fun overview_stage(item : model, runtime_tree : list<state_entry>, results : list<test_result>) : <div> (model, list<state_entry>, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val (todo_item, next_runtime_tree, todo_node, todo_effects, todo_handlers) = run_todo_panel(item, runtime_tree)
  val (lab_item, next_runtime_tree2, lab_node, lab_effects, lab_handlers) = run_lab_panel(todo_item, next_runtime_tree)
  val (effects_item, effects_node, effects, handlers) = run_effects_panel(lab_item, results)
  (effects_item, next_runtime_tree2, div(props(class = "overview-grid"), [
    div(props(class = "overview-main"), [
      todo_node,
    ]),
    aside(props(class = "overview-side"), [
      tests_panel(results),
    ]),
    div(props(class = "overview-wide"), [
      lab_node,
    ]),
    div(props(class = "overview-wide"), [
      effects_node,
    ]),
  ]), append_scheduled_effects(append_scheduled_effects(todo_effects, lab_effects), effects), append_event_registries(append_event_registries(todo_handlers, lab_handlers), handlers))

fun route_stage(item : model, runtime_tree : list<state_entry>, results : list<test_result>) : <div> (model, list<state_entry>, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  if item.route_name == "todo" then
    map_component_tree_run(run_todo_panel(item, runtime_tree), fn(_next_item, todo_node) wrap_single_stage(todo_node))
  else if route_is_lab(item.route_name) then {
    val (next_item, next_runtime_tree, lab_node, effects, handlers) = run_lab_panel(item, runtime_tree)
    (next_item, next_runtime_tree, wrap_single_stage(lab_node), effects, handlers)
  }
  else if route_is_effects(item.route_name) then {
    val (next_item, effects_node, effects, handlers) = run_effects_panel(item, results)
    (next_item, runtime_tree, wrap_single_stage(effects_node), effects, handlers)
  }
  else if item.route_name == "checks" then
    (item, runtime_tree, wrap_single_stage(tests_panel(results)), Nil, empty_event_registry())
  else
    overview_stage(item, runtime_tree, results)

pub fun render_layout(item : model, runtime_tree : list<state_entry>, results : list<test_result>) : <hook_scope,listener_registry<model,browser_event_effect>,div> (model, list<state_entry>, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  val stage_run = route_stage(item, runtime_tree, results)
  map_component_tree_run(stage_run, fn(owner, current_stage) section_key("app", props(class = "shell app-shell"), [
    intro_panel(owner),
    route_bar(owner),
    current_stage,
  ]))
