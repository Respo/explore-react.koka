module explore/react/inspection

import explore/react/core
import explore/react/state

// Read-only VDOM and component-runtime queries belong to tests, devtools, and
// host inspection. Component authoring modules do not import this module.

pub fun vnode_find_key(node : vnode, target_key : string) : <div> maybe<vnode>
  if vnode/key(node) == target_key then Just(node)
  else vnode_find_key_in_children(vnode/children(node), target_key)

fun vnode_find_key_in_children(children : list<vnode>, target : string) : <div> maybe<vnode>
  match children
    Nil -> Nothing
    Cons(child, rest) ->
      match vnode_find_key(child, target)
        Just(found) -> Just(found)
        Nothing -> vnode_find_key_in_children(rest, target)

pub fun vnode_find_attr_value(node : vnode, name : string, value : string) : <div> maybe<vnode>
  if vnode_get_attr(node, name) == value then Just(node)
  else vnode_find_attr_value_in_children(vnode/children(node), name, value)

fun vnode_find_attr_value_in_children(children : list<vnode>, name : string, value : string) : <div> maybe<vnode>
  match children
    Nil -> Nothing
    Cons(child, rest) ->
      match vnode_find_attr_value(child, name, value)
        Just(found) -> Just(found)
        Nothing -> vnode_find_attr_value_in_children(rest, name, value)

pub fun vnode_find_text(node : vnode, target_text : string) : <div> maybe<vnode>
  if vnode/text(node) == target_text then Just(node)
  else vnode_find_text_in_children(vnode/children(node), target_text)

fun vnode_find_text_in_children(children : list<vnode>, target_text : string) : <div> maybe<vnode>
  match children
    Nil -> Nothing
    Cons(child, rest) ->
      match vnode_find_text(child, target_text)
        Just(found) -> Just(found)
        Nothing -> vnode_find_text_in_children(rest, target_text)

pub fun vnode_get_attr(node : vnode, name : string) : string
  find_vnode_attr(vnode/attrs(node), name)

fun find_vnode_attr(attrs : list<attr>, name : string) : string
  match attrs
    Nil -> ""
    Cons(item, rest) -> if attr/name(item) == name then attr/value(item) else find_vnode_attr(rest, name)

pub fun vnode_click_payload(node : vnode) : string
  find_listener_payload_by_kind(vnode/listeners(node), Click_event)

pub fun vnode_input_channel(node : vnode) : string
  find_listener_payload_by_kind(vnode/listeners(node), Input_event)

fun find_listener_payload_by_kind(listeners : list<listener>, target : dom_event_kind) : string
  match listeners
    Nil -> ""
    Cons(item, rest) ->
      match (listener/kind(item), target)
        (Click_event, Click_event) -> listener/payload(item)
        (Input_event, Input_event) -> listener/payload(item)
        (Enter_event, Enter_event) -> listener/payload(item)
        _ -> find_listener_payload_by_kind(rest, target)

fun find_click_in_list<s,e::E>(items : list<registered_click<s,e>>, target_id : string) : <div> maybe<registered_click<s,e>>
  match items
    Nil -> Nothing
    Cons(item, rest) -> if registered_click/id(item) == target_id then Just(item) else find_click_in_list(rest, target_id)

pub fun find_registered_click<s,e::E>(registry : event_registry<s,e>, target_id : string) : <div> maybe<registered_click<s,e>>
  find_click_in_list(event_registry/clicks(registry), target_id)

fun find_click_by_semantic_in_list<s,e::E>(items : list<registered_click<s,e>>, semantic : string) : <div> maybe<registered_click<s,e>>
  match items
    Nil -> Nothing
    Cons(item, rest) ->
      if registered_click/semantic_name(item) == semantic then Just(item)
      else find_click_by_semantic_in_list(rest, semantic)

pub fun find_registered_click_by_semantic<s,e::E>(registry : event_registry<s,e>, semantic : string) : <div> maybe<registered_click<s,e>>
  find_click_by_semantic_in_list(event_registry/clicks(registry), semantic)

fun find_input_in_list<s,e::E>(items : list<registered_input<s,e>>, target_id : string) : <div> maybe<registered_input<s,e>>
  match items
    Nil -> Nothing
    Cons(item, rest) -> if registered_input/id(item) == target_id then Just(item) else find_input_in_list(rest, target_id)

pub fun find_registered_input<s,e::E>(registry : event_registry<s,e>, target_id : string) : <div> maybe<registered_input<s,e>>
  find_input_in_list(event_registry/inputs(registry), target_id)

fun find_input_by_semantic_in_list<s,e::E>(items : list<registered_input<s,e>>, semantic : string) : <div> maybe<registered_input<s,e>>
  match items
    Nil -> Nothing
    Cons(item, rest) ->
      if registered_input/semantic_name(item) == semantic then Just(item)
      else find_input_by_semantic_in_list(rest, semantic)

pub fun find_registered_input_by_semantic<s,e::E>(registry : event_registry<s,e>, semantic : string) : <div> maybe<registered_input<s,e>>
  find_input_by_semantic_in_list(event_registry/inputs(registry), semantic)

pub fun count_registered_clicks<s,e::E>(registry : event_registry<s,e>) : <div> int
  event_registry/clicks(registry).length

pub fun count_registered_inputs<s,e::E>(registry : event_registry<s,e>) : <div> int
  event_registry/inputs(registry).length

fun semantic_drift_warning(handler_id : string, previous_semantic : string, next_semantic : string) : string
  "Listener semantic drift for `" ++ handler_id ++ "`: `" ++ previous_semantic ++ "` -> `" ++ next_semantic ++ "`. Consider using a new named listener or splitting the conditional branch."

fun compare_click_semantics<s,e::E>(previous : list<registered_click<s,e>>, next : list<registered_click<s,e>>) : <div> list<string>
  match next
    Nil -> Nil
    Cons(item, rest) ->
      val tail = compare_click_semantics(previous, rest)
      match find_click_in_list(previous, registered_click/id(item))
        Just(found) -> if registered_click/semantic_name(found) == registered_click/semantic_name(item) then tail else Cons(semantic_drift_warning(registered_click/id(item), registered_click/semantic_name(found), registered_click/semantic_name(item)), tail)
        Nothing -> tail

fun compare_input_semantics<s,e::E>(previous : list<registered_input<s,e>>, next : list<registered_input<s,e>>) : <div> list<string>
  match next
    Nil -> Nil
    Cons(item, rest) ->
      val tail = compare_input_semantics(previous, rest)
      match find_input_in_list(previous, registered_input/id(item))
        Just(found) -> if registered_input/semantic_name(found) == registered_input/semantic_name(item) then tail else Cons(semantic_drift_warning(registered_input/id(item), registered_input/semantic_name(found), registered_input/semantic_name(item)), tail)
        Nothing -> tail

pub fun event_registry_semantic_warnings<s,e::E>(previous : event_registry<s,e>, next : event_registry<s,e>) : <div> list<string>
  compare_click_semantics(event_registry/clicks(previous), event_registry/clicks(next)) ++ compare_input_semantics(event_registry/inputs(previous), event_registry/inputs(next))

pub fun count_entries(tree : list<state_entry>) : <div> int
  tree.length
