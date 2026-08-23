module demo/runtimeframe

import demo/model
import explore/react/state

pub struct runtime_frame(owner : model, runtime_tree : list<state_entry>)

pub fun current_runtime_frame(owner : model, runtime_tree : list<state_entry>) : runtime_frame
  Runtime_frame(owner, runtime_tree)

pub fun run_runtime_action<e>(frame : runtime_frame, action : (model) -> <local_state_read,local_state_write,div|e> model) : <div|e> runtime_frame
  val (next_owner, next_tree) = run_local_action(runtime_frame/runtime_tree(frame), fn() action(runtime_frame/owner(frame)))
  Runtime_frame(next_owner, next_tree)
