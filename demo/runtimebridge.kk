module demo/runtimebridge

import demo/lab/state
import demo/model
import demo/runtimeowner
import demo/todo/state
import explore/react/state

pub fun uses_external_runtime_tree(path : string) : bool
  is-just(starts-with(path, todo_panel_scope_path())) || is-just(starts-with(path, lab_panel_scope_path()))

pub fun run_with_runtime_tree<e>(
  path : string,
  owner : model,
  runtime_tree : list<state_entry>,
  action : (model) -> <div|e> model
) : <div|e> (model, list<state_entry>)
  if uses_external_runtime_tree(path) then
    runtimeowner/detach_runtime_tree(action(runtimeowner/attach_runtime_tree(owner, runtime_tree)))
  else
    (action(owner), runtime_tree)