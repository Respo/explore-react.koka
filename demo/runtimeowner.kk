module demo/runtimeowner

import demo/model
import explore/react/state

pub fun attach_runtime_tree(owner : model, runtime_tree : list<state_entry>) : model
  owner(app_local_tree = runtime_tree)

pub fun detach_runtime_tree(owner : model) : (model, list<state_entry>)
  (owner(app_local_tree = Nil), owner.app_local_tree)

pub fun attached_runtime_tree(owner : model) : list<state_entry>
  owner.app_local_tree

pub fun map_attached_runtime_tree(owner : model, transform : (list<state_entry>) -> <div> list<state_entry>) : <div> model
  attach_runtime_tree(owner, transform(attached_runtime_tree(owner)))

pub fun run_attached_local_state<e>(
  owner : model,
  action : () -> <local_state_read,local_state_write,hook_effects,hook_scope,hook_state,div|e> model
) : <div|e> model
  val (next_model, next_tree, _pending_effects) = run_local_state(attached_runtime_tree(owner), action)
  attach_runtime_tree(next_model, next_tree)
