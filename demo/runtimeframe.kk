module demo/runtimeframe

import demo/model
import explore/react/action
import explore/react/state

pub struct runtime_frame(owner : model, runtime_tree : list<state_entry>)

pub fun current_runtime_frame(owner : model, runtime_tree : list<state_entry>) : runtime_frame
  Runtime_frame(owner, runtime_tree)

pub fun run_runtime_action_observed<e>(frame : runtime_frame, action : (model) -> <action_observation,local_state_read,local_state_write,div|e> model) : <div|e> (runtime_frame, list<action_envelope>)
  val (result, actions) = capture_actions(fn() run_local_action(runtime_frame/runtime_tree(frame), fn() action(runtime_frame/owner(frame))))
  val (next_owner, next_tree) = result
  (Runtime_frame(next_owner, next_tree), actions)

pub fun run_runtime_action<e>(frame : runtime_frame, action : (model) -> <action_observation,local_state_read,local_state_write,div|e> model) : <div|e> runtime_frame
  discard_actions(fn() {
    val (next_owner, next_tree) = run_local_action(runtime_frame/runtime_tree(frame), fn() action(runtime_frame/owner(frame)))
    Runtime_frame(next_owner, next_tree)
  })

pub fun run_runtime_render<a,e::E>(
  frame : runtime_frame,
  render : (model) -> <component_runtime,div> (model, a, list<scheduled_effect>, event_registry<model,e>)
) : <div> (runtime_frame, a, list<scheduled_effect>, event_registry<model,e>)
  val (rendered, next_tree) = with_component_runtime(runtime_frame/runtime_tree(frame), fn() render(runtime_frame/owner(frame)))
  val (next_owner, result, effects, registry) = rendered
  (Runtime_frame(next_owner, next_tree), result, effects, registry)
