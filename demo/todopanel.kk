module demo/todopanel

import demo/model
import demo/todo/events
import demo/todo/view
import demo/todo/viewmodel
import explore/react/core
import explore/react/state

pub fun run_todo_panel(item : model, runtime_tree : list<state_entry>) : <div> (model, list<state_entry>, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  run_stateful_component_with_tree(
    item,
    runtime_tree,
    fn(owner) component_root("todo", "panel", fn() render_todo_panel(owner, todo_panel_state_of(owner))))

pub fun todo_panel(item : model, runtime_tree : list<state_entry>) : <div> vnode
  val (_next_item, _next_runtime_tree, panel_node, _pending_effects, _handlers) = run_todo_panel(item, runtime_tree)
  panel_node
