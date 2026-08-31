module examples/first_component/main

import examples/first_component/component
import explore/react/action
import explore/react/core
import explore/react/inspection
import explore/react/renderer
import explore/react/runtime
import explore/react/state

fun initial_render() : <div> (vnode, list<state_entry>, event_registry<(),disclosure_event_effect>)
  val ((node, tree, _effects), registry) = run_event_registry(fn() run_local_state(Nil, fn() disclosure_panel()))
  (node, tree, registry)

fun toggle(tree : list<state_entry>, registry : event_registry<(),disclosure_event_effect>) : <div> (list<state_entry>, list<action_envelope>)
  match find_registered_click_by_semantic(registry, "toggle-disclosure")
    Nothing -> (tree, Nil)
    Just(listener) -> {
      val ((_owner, next_tree), actions) = capture_actions(fn() run_local_action(tree, fn() run_registered_click(listener, ())))
      (next_tree, actions)
    }

fun updated_render(tree : list<state_entry>) : <div> vnode
  val ((node, _next_tree, _effects), _registry) = run_event_registry(fn() run_local_state(tree, fn() disclosure_panel()))
  node

fun action_summary(actions : list<action_envelope>) : string
  match actions
    [action] -> match decode_action(disclosure_action_codec, action)
      Just(Toggle_disclosure) -> "Toggle_disclosure " ++ action.schema ++ "@" ++ action.version.show ++ " payload=" ++ action.payload
      Nothing -> "<unreadable action>"
    Nil -> "<missing>"
    _ -> "<unexpected action count>"

fun main() : io ()
  val (before, tree, registry) = initial_render()
  val (next_tree, actions) = toggle(tree, registry)
  val after = updated_render(next_tree)
  println("Initial UI: " ++ render_node("0", before))
  println("Typed action: " ++ action_summary(actions))
  println("Updated UI: " ++ render_node("0", after))
