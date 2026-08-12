module demo/runtimeframe

import demo/model
import demo/runtimebridge
import explore/react/state

pub struct runtime_frame(owner : model, runtime_tree : list<state_entry>)

pub fun current_runtime_frame(owner : model, runtime_tree : list<state_entry>) : runtime_frame
  Runtime_frame(owner, runtime_tree)

pub fun map_runtime_owner<e>(frame : runtime_frame, action : (model) -> <div|e> model) : <div|e> runtime_frame
  Runtime_frame(action(runtime_frame/owner(frame)), runtime_frame/runtime_tree(frame))

pub fun run_runtime_path<e>(path : string, frame : runtime_frame, action : (model) -> <div|e> model) : <div|e> runtime_frame
  val (next_owner, next_tree) = runtimebridge/run_with_runtime_tree(path, runtime_frame/owner(frame), runtime_frame/runtime_tree(frame), action)
  Runtime_frame(next_owner, next_tree)