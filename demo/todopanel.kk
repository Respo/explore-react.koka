module demo/todopanel

import demo/model
import demo/todo/events
import demo/todo/view
import demo/todo/viewmodel
import explore/react/core
import explore/react/state

pub fun run_todo_panel(item : model) : <component_runtime,div> (model, vnode, list<scheduled_effect>, event_registry<model,browser_event_effect>)
  run_component(
    item,
    group = "todo",
    key = "panel",
    render = fn(owner) render_todo_panel(todo_panel_state_of(owner)))
