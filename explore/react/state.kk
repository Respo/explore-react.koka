module explore/react/state

import explore/react/action
import explore/react/core

pub effect local_state_read
  fun use_named_state<a>(entry_slot : state_slot, codec : state_codec<a>, fallback : a) : a

pub effect local_state_write
  fun set_named_state<a>(entry_slot : state_slot, codec : state_codec<a>, value : a) : ()
  fun update_named_state<a>(entry_slot : state_slot, codec : state_codec<a>, fallback : a, update : (a) -> a) : ()
  fun clear_local_state(path : string) : ()

pub effect hook_effects
  fun use_named_effect(effect_slot : state_slot, deps : list<string>, action : () -> io ()) : ()
  fun use_effect(deps : list<string>, action : () -> io ()) : ()

pub effect hook_scope
  fun push_hook_scope(scope_name : string) : ()
  fun pop_hook_scope() : ()
  fun current_hook_scope_name() : string

pub effect component_runtime
  fun get_component_state_entries() : list<state_entry>
  fun set_component_state_entries(tree : list<state_entry>) : ()

pub effect hook_state
  fun use_state<a>(fallback : a, ?state_codec : state_codec<a>) : a
  fun use_state_pair<a>(fallback : a, ?state_codec : state_codec<a>) : (a, (a) -> <local_state_write,div> ())

pub effect listener_registry<s,e::E>
  fun register_listener(entry_slot : state_slot, registration : listener_registration<s,e>) : listener

pub type listener_registration<s,e::E>
  Click_registration(semantic_name : string, run : (s) -> <div|e> s)
  Input_registration(semantic_name : string, run : (string, s) -> <action_observation,local_state_read,local_state_write,div> s)
  Enter_registration(semantic_name : string, run : (s) -> <div|e> s)

pub struct state_slot(path : string)

// The runtime tree is deliberately type-erased, but every cell keeps enough
// schema information to be decoded by newer code after a hot reload.
pub struct state_codec<a>(schema : string, version : int, decode : (int, string) -> maybe<a>, encode : (a) -> string)

pub struct state_entry(path : string, schema : string, version : int, payload : string)

// A component store keeps state and actions typed inside business code. Only
// state entries and action messages cross the type-erased runtime boundary.
pub struct store_spec<s,a>(name : string, state_codec : state_codec<s>, action_codec : action_codec<a>, reduce : (s, a) -> s)
pub struct store_binding<s,a>(current : s, send : (a) -> <action_observation,local_state_write,div> ())

inline extern snapshot_escape(text : string) : string
  js inline "encodeURIComponent(#1)"

inline extern snapshot_unescape(text : string) : string
  js inline "((s) => { try { return decodeURIComponent(s); } catch (_) { return ''; } })(#1)"

inline extern snapshot_unescape_valid(text : string) : bool
  js inline "((s) => { try { decodeURIComponent(s); return true; } catch (_) { return false; } })(#1)"

pub struct scheduled_effect(path : string, run : () -> io ())
pub struct registered_click<s,e::E>(id : string, semantic_name : string, run : (s) -> <div|e> s)
pub struct registered_input<s>(id : string, semantic_name : string, run : (string, s) -> <action_observation,local_state_read,local_state_write,div> s)
pub struct event_registry<s,e::E>(clicks : list<registered_click<s,e>>, inputs : list<registered_input<s>>, warnings : list<string>)
struct hook_frame(scope_name : string, next_state_index : int, next_effect_index : int)

fun state_codec_read(item : state_codec<a>, entry : state_entry) : maybe<a>
  item.decode.(entry.version, entry.payload)

fun state_codec_write(item : state_codec<a>, path : string, value : a) : state_entry
  State_entry(path, item.schema, item.version, item.encode.(value))

fun join_slot_path(base : string, name : string) : string
  if base == "" then name else base ++ "/" ++ name

fun normalize_slot_name(name : string) : string
  match list(name)
    Nil -> "slot"
    Cons(head, _rest) -> if head >= '0' && head <= '9' then "_" ++ name else name

fun named_slot(base : string, name : string) : state_slot
  State_slot(join_slot_path(base, normalize_slot_name(name)))

fun hook_state_slot(scope_base : string, index : int) : state_slot
  State_slot(join_slot_path(join_slot_path(scope_base, "state"), index.show))

fun hook_effect_slot(scope_base : string, index : int) : state_slot
  State_slot(join_slot_path(join_slot_path(scope_base, "effect"), index.show))

fun child_scope(scope_base : string, group_name : string, key_name : string) : string
  join_slot_path(join_slot_path(scope_base, normalize_slot_name(group_name)), normalize_slot_name(key_name))

// Stable, inspectable component path for business code that coordinates a child
// component outside its render body. Slot and hook ordering remain internal.
pub fun component_child_path(scope_base : string, group_name : string, key_name : string) : string
  child_scope(scope_base, group_name, key_name)

// For code that needs to inspect or mutate hook-managed state outside the component body,
// prefer semantic hook slot names over manual indices. Runtime hook ordering still stays internal.
fun hook_named_state_slot(scope_base : string, name : string) : state_slot
  named_slot(join_slot_path(scope_base, "state"), name)

fun hook_named_effect_slot(scope_base : string, name : string) : state_slot
  named_slot(join_slot_path(scope_base, "effect"), name)

fun named_listener_slot(scope_base : string, kind : dom_event_kind, name : string) : state_slot
  State_slot(join_slot_path(join_slot_path(join_slot_path(scope_base, "listeners"), dom_event_kind_name(kind)), normalize_slot_name(name)))

pub val string/state_codec : state_codec<string> = State_codec(
  "respo/string",
  1,
  fn(version, payload) if version == 1 then Just(payload) else Nothing,
  fn(value) value)

pub val bool/state_codec : state_codec<bool> = State_codec(
  "respo/bool",
  1,
  fn(version, payload) {
    if version != 1 then Nothing
    else if payload == "true" then Just(True)
    else if payload == "false" then Just(False)
    else Nothing
  },
  fn(value) if value then "true" else "false")

pub fun run_registered_click<s,e::E>(item : registered_click<s,e>, owner : s) : <div|e> s
  item.run.(owner)

pub fun run_registered_input<s>(item : registered_input<s>, value : string, owner : s) : <action_observation,local_state_read,local_state_write,div> s
  item.run.(value, owner)

pub fun empty_event_registry<s,e::E>() : event_registry<s,e>
  Event_registry(Nil, Nil, Nil)

pub fun pure_component_run<s,e::E,a>(owner : s, result : a) : <div> (s, a, list<scheduled_effect>, event_registry<s,e>)
  (owner, result, Nil, empty_event_registry())

pub fun with_component_runtime<a,e>(tree : list<state_entry>, action : () -> <component_runtime|e> a) : e (a, list<state_entry>)
  var next_tree := tree
  with return(result) (result, next_tree)
  with handler
    fun get_component_state_entries() next_tree
    fun set_component_state_entries(next_value) next_tree := next_value
  action()

pub fun run_scheduled_effect(item : scheduled_effect) : io ()
  item.run.()

fun append_registered_click<s,e::E>(items : list<registered_click<s,e>>, item : registered_click<s,e>) : <div> list<registered_click<s,e>>
  match items
    Nil -> [item]
    Cons(head, rest) -> Cons(head, append_registered_click(rest, item))

fun append_registered_input<s>(items : list<registered_input<s>>, item : registered_input<s>) : <div> list<registered_input<s>>
  match items
    Nil -> [item]
    Cons(head, rest) -> Cons(head, append_registered_input(rest, item))

fun append_messages(left : list<string>, right : list<string>) : <div> list<string>
  match left
    Nil -> right
    Cons(head, rest) -> Cons(head, append_messages(rest, right))

fun merge_registered_clicks<s,e::E>(left : list<registered_click<s,e>>, right : list<registered_click<s,e>>, warnings : list<string>) : <div> (list<registered_click<s,e>>, list<string>)
  match right
    Nil -> (left, warnings)
    Cons(item, rest) ->
      match find_click_in_list(left, registered_click/id(item))
        Just(found) -> merge_registered_clicks(replace_registered_click(left, item), rest, Cons(if registered_click/semantic_name(found) == registered_click/semantic_name(item) then duplicate_listener_warning(registered_click/id(item), registered_click/semantic_name(item)) else semantic_drift_warning(registered_click/id(item), registered_click/semantic_name(found), registered_click/semantic_name(item)), warnings))
        Nothing -> merge_registered_clicks(append_registered_click(left, item), rest, warnings)

fun merge_registered_inputs<s>(left : list<registered_input<s>>, right : list<registered_input<s>>, warnings : list<string>) : <div> (list<registered_input<s>>, list<string>)
  match right
    Nil -> (left, warnings)
    Cons(item, rest) ->
      match find_input_in_list(left, registered_input/id(item))
        Just(found) -> merge_registered_inputs(replace_registered_input(left, item), rest, Cons(if registered_input/semantic_name(found) == registered_input/semantic_name(item) then duplicate_listener_warning(registered_input/id(item), registered_input/semantic_name(item)) else semantic_drift_warning(registered_input/id(item), registered_input/semantic_name(found), registered_input/semantic_name(item)), warnings))
        Nothing -> merge_registered_inputs(append_registered_input(left, item), rest, warnings)

pub fun append_event_registries<s,e::E>(left : event_registry<s,e>, right : event_registry<s,e>) : <div> event_registry<s,e>
  match left
    Event_registry(left_clicks, left_inputs, left_warnings) ->
      match right
        Event_registry(right_clicks, right_inputs, right_warnings) -> {
          val (merged_clicks, click_warnings) = merge_registered_clicks(left_clicks, right_clicks, append_messages(left_warnings, right_warnings))
          val (merged_inputs, merged_warnings) = merge_registered_inputs(left_inputs, right_inputs, click_warnings)
          Event_registry(merged_clicks, merged_inputs, merged_warnings)
        }

fun append_registered_clicks<s,e::E>(left : list<registered_click<s,e>>, right : list<registered_click<s,e>>) : <div> list<registered_click<s,e>>
  match left
    Nil -> right
    Cons(head, rest) -> Cons(head, append_registered_clicks(rest, right))

fun append_registered_inputs<s>(left : list<registered_input<s>>, right : list<registered_input<s>>) : <div> list<registered_input<s>>
  match left
    Nil -> right
    Cons(head, rest) -> Cons(head, append_registered_inputs(rest, right))

pub fun find_registered_click<s,e::E>(registry : event_registry<s,e>, target_id : string) : <div> maybe<registered_click<s,e>>
  find_click_in_list(event_registry/clicks(registry), target_id)

fun find_click_in_list<s,e::E>(items : list<registered_click<s,e>>, target_id : string) : <div> maybe<registered_click<s,e>>
  match items
    Nil -> Nothing
    Cons(item, rest) -> if registered_click/id(item) == target_id then Just(item) else find_click_in_list(rest, target_id)

// Find the first registered click whose semantic name matches.
// Useful in tests that know the handler name but not the generated slot path.
pub fun find_registered_click_by_semantic<s,e::E>(registry : event_registry<s,e>, semantic : string) : <div> maybe<registered_click<s,e>>
  find_click_by_semantic_in_list(event_registry/clicks(registry), semantic)

fun find_click_by_semantic_in_list<s,e::E>(items : list<registered_click<s,e>>, semantic : string) : <div> maybe<registered_click<s,e>>
  match items
    Nil -> Nothing
    Cons(item, rest) ->
      if registered_click/semantic_name(item) == semantic then Just(item)
      else find_click_by_semantic_in_list(rest, semantic)

pub fun find_registered_input<s,e::E>(registry : event_registry<s,e>, target_id : string) : <div> maybe<registered_input<s>>
  find_input_in_list(event_registry/inputs(registry), target_id)

fun find_input_in_list<s>(items : list<registered_input<s>>, target_id : string) : <div> maybe<registered_input<s>>
  match items
    Nil -> Nothing
    Cons(item, rest) -> if registered_input/id(item) == target_id then Just(item) else find_input_in_list(rest, target_id)

// Find the first registered input whose semantic name matches.
pub fun find_registered_input_by_semantic<s,e::E>(registry : event_registry<s,e>, semantic : string) : <div> maybe<registered_input<s>>
  find_input_by_semantic_in_list(event_registry/inputs(registry), semantic)

fun find_input_by_semantic_in_list<s>(items : list<registered_input<s>>, semantic : string) : <div> maybe<registered_input<s>>
  match items
    Nil -> Nothing
    Cons(item, rest) ->
      if registered_input/semantic_name(item) == semantic then Just(item)
      else find_input_by_semantic_in_list(rest, semantic)

pub fun count_registered_clicks<s,e::E>(registry : event_registry<s,e>) : <div> int
  count_click_items(event_registry/clicks(registry))

fun count_click_items<s,e::E>(items : list<registered_click<s,e>>) : <div> int
  match items
    Nil -> 0
    Cons(_, rest) -> 1 + count_click_items(rest)

pub fun count_registered_inputs<s,e::E>(registry : event_registry<s,e>) : <div> int
  count_input_items(event_registry/inputs(registry))

fun count_input_items<s>(items : list<registered_input<s>>) : <div> int
  match items
    Nil -> 0
    Cons(_, rest) -> 1 + count_input_items(rest)

fun compare_click_semantics<s,e::E>(previous : list<registered_click<s,e>>, next : list<registered_click<s,e>>) : <div> list<string>
  match next
    Nil -> Nil
    Cons(item, rest) ->
      val tail = compare_click_semantics(previous, rest)
      match find_click_in_list(previous, registered_click/id(item))
        Just(found) -> if registered_click/semantic_name(found) == registered_click/semantic_name(item) then tail else Cons(semantic_drift_warning(registered_click/id(item), registered_click/semantic_name(found), registered_click/semantic_name(item)), tail)
        Nothing -> tail

fun compare_input_semantics<s>(previous : list<registered_input<s>>, next : list<registered_input<s>>) : <div> list<string>
  match next
    Nil -> Nil
    Cons(item, rest) ->
      val tail = compare_input_semantics(previous, rest)
      match find_input_in_list(previous, registered_input/id(item))
        Just(found) -> if registered_input/semantic_name(found) == registered_input/semantic_name(item) then tail else Cons(semantic_drift_warning(registered_input/id(item), registered_input/semantic_name(found), registered_input/semantic_name(item)), tail)
        Nothing -> tail

pub fun event_registry_semantic_warnings<s,e::E>(previous : event_registry<s,e>, next : event_registry<s,e>) : <div> list<string>
  append_messages(compare_click_semantics(event_registry/clicks(previous), event_registry/clicks(next)), compare_input_semantics(event_registry/inputs(previous), event_registry/inputs(next)))

fun state_value(tree : list<state_entry>, entry_slot : state_slot, fallback : a, ?state_codec : state_codec<a>) : <div> a
  match find_state(tree, state_slot/path(entry_slot))
    Just(item) ->
      if item.schema != state_codec.schema then fallback
      else state_codec_read(state_codec, item).default(fallback)
    _ -> fallback

fun assoc_slot_value(tree : list<state_entry>, entry_slot : state_slot, value : a, ?state_codec : state_codec<a>) : <div> list<state_entry>
  assoc_entry(tree, state_codec_write(state_codec, state_slot/path(entry_slot), value))

fun clear_slot_state(tree : list<state_entry>, entry_slot : state_slot) : <div> list<state_entry>
  clear_state(tree, state_slot/path(entry_slot))

fun set_slot_state(entry_slot : state_slot, value : a, ?state_codec : state_codec<a>) : <local_state_write,div> ()
  set_named_state(entry_slot, state_codec, value)

fun use_named_state_pair(entry_slot : state_slot, fallback : a, ?state_codec : state_codec<a>) : <local_state_read,div> (a, (a) -> <local_state_write,div> ())
  (use_named_state(entry_slot, state_codec, fallback), fn(value) set_named_state(entry_slot, state_codec, value))

// React-like hook helpers: `component(...)` declares one stable scope per component,
// and plain `use_state(...)` / `use_effect(...)` then consume numbered slots automatically.
// When you need an explicit path, use the `use_named_*` variants instead.

pub fun with_hook_scope(scope_name : string, action : () -> <hook_scope|e> a) : <hook_scope|e> a
  push_hook_scope(scope_name)
  val result = action()
  pop_hook_scope()
  result

pub fun component(scope_name : string, render : () -> <hook_scope|e> a) : <hook_scope|e> a
  with_hook_scope(scope_name, render)

// Use this for root-owned keyed components so business code does not have to spell
// `component(component_local_path(...), ...)` just to declare one stable component boundary.
pub fun component_root(group_name : string, key_name : string, render : () -> <hook_scope|e> a) : <hook_scope|e> a
  component(component_local_path(group_name, key_name), render)

pub fun component_in(group_name : string, key_name : string, render : () -> <hook_scope|e> a) : <hook_scope|e> a
  component(child_scope(current_hook_scope_name(), group_name, key_name), render)

// Render a keyed collection of child components without exposing scope-path
// construction or repeating a one-line `map(... component_in(...))` helper.
pub fun components<a,e>(
  items : list<a>,
  group : string,
  key : (a) -> string,
  render : (a) -> <hook_scope|e> vnode
) : <hook_scope|e> list<vnode>
  map(items, fn(item) component_in(group, key(item), fn() render(item)))

pub fun component_local_path(group_name : string, key_name : string) : string
  component_child_path("", group_name, key_name)

fun local_named_state_slot(name : string) : <hook_scope,div> state_slot
  hook_named_state_slot(current_hook_scope_name(), name)

fun local_named_effect_slot(name : string) : <hook_scope,div> state_slot
  hook_named_effect_slot(current_hook_scope_name(), name)

// The component-state surface deliberately starts with `state`: it makes local
// state stand out from regular values, while named arguments keep identity and
// initialization visible at every call site.
pub fun state<a>(name : string, initial : a, ?state_codec : state_codec<a>) : <hook_scope,local_state_read,div> a
  use_named_state(local_named_state_slot(name), state_codec, initial)

pub fun state_pair<a>(name : string, initial : a, ?state_codec : state_codec<a>) : <hook_scope,local_state_read,div> (a, (a) -> <local_state_write,div> ())
  use_named_state_pair(local_named_state_slot(name), initial)

// Reducer-backed local state. A component emits typed actions instead of
// coordinating several setters, while the runtime stores one versioned cell.
pub fun use_store<s,a>(spec : store_spec<s,a>, initial : s) : <hook_scope,local_state_read,div> store_binding<s,a>
  val scope = current_hook_scope_name()
  val entry_slot = local_named_state_slot(spec.name)
  val codec = spec.state_codec
  val current = use_named_state(entry_slot, codec, initial)
  Store_binding(current, fn(action) {
    emit_action(source = "component", target = scope, codec = spec.action_codec, action = action)
    update_named_state(entry_slot, codec, initial, fn(latest) spec.reduce.(latest, action))
  })

// Store access outside a component render still speaks in typed state/actions.
// Scope and serialization stay inside the framework boundary.
pub fun current_store_state<s,a>(scope : string, spec : store_spec<s,a>, initial : s) : <local_state_read,div> s
  use_named_state(hook_named_state_slot(scope, spec.name), spec.state_codec, initial)

pub fun dispatch_store<s,a>(scope : string, spec : store_spec<s,a>, initial : s, action : a) : <action_observation,local_state_write,div> ()
  emit_action(source = "component", target = scope, codec = spec.action_codec, action = action)
  update_named_state(hook_named_state_slot(scope, spec.name), spec.state_codec, initial, fn(latest) spec.reduce.(latest, action))

pub fun encode_store_action<s,a>(target : string, spec : store_spec<s,a>, action : a) : action_envelope
  encode_action(source = "component", target = target, codec = spec.action_codec, action = action)

pub fun decode_store_action<s,a>(spec : store_spec<s,a>, message : action_envelope) : maybe<a>
  if message.source != "component" then Nothing
  else decode_action(spec.action_codec, message)

pub fun read_store_state<s,a>(tree : list<state_entry>, scope_name : string, spec : store_spec<s,a>, initial : s) : <div> s
  read_named_local_state(tree, scope_name, spec.name, initial, spec.state_codec)

pub fun clear_store_state<s,a>(scope_name : string, spec : store_spec<s,a>) : <local_state_write,div> ()
  clear_named_local_state(scope_name, spec.name)

pub fun state_effect(name : string, deps : list<string>, action : () -> io ()) : <hook_scope,hook_effects,div> ()
  use_named_effect(local_named_effect_slot(name), deps, action)

// Business code that must coordinate a component's local state outside its
// render body uses a semantic name, never a hook index or codec.
pub fun named_local_state_path(scope_name : string, state_name : string) : string
  state_slot/path(hook_named_state_slot(scope_name, state_name))

pub fun named_local_effect_path(scope_name : string, effect_name : string) : string
  state_slot/path(hook_named_effect_slot(scope_name, effect_name))

pub fun named_local_listener_path(scope_name : string, kind : dom_event_kind, listener_name : string) : string
  state_slot/path(named_listener_slot(scope_name, kind, listener_name))

pub fun read_named_local_state<a>(tree : list<state_entry>, scope_name : string, state_name : string, fallback : a, ?state_codec : state_codec<a>) : <div> a
  state_value(tree, hook_named_state_slot(scope_name, state_name), fallback)

pub fun assoc_named_local_state<a>(tree : list<state_entry>, scope_name : string, state_name : string, value : a, ?state_codec : state_codec<a>) : <div> list<state_entry>
  assoc_slot_value(tree, hook_named_state_slot(scope_name, state_name), value)

pub fun set_named_local_state<a>(scope_name : string, state_name : string, value : a, ?state_codec : state_codec<a>) : <local_state_write,div> ()
  set_slot_state(hook_named_state_slot(scope_name, state_name), value)

pub fun clear_named_local_state(scope_name : string, state_name : string) : <local_state_write,div> ()
  clear_slot(hook_named_state_slot(scope_name, state_name))

pub fun clear_named_local_state_in_tree(tree : list<state_entry>, scope_name : string, state_name : string) : <div> list<state_entry>
  clear_slot_state(tree, hook_named_state_slot(scope_name, state_name))

pub fun root_listener_path(kind : dom_event_kind, name : string) : string
  state_slot/path(named_listener_slot("", kind, name))

pub fun component_listener_path(group_name : string, key_name : string, kind : dom_event_kind, name : string) : string
  state_slot/path(named_listener_slot(component_local_path(group_name, key_name), kind, name))

pub fun root_effect_path(name : string) : string
  state_slot/path(hook_named_effect_slot("", name))

pub fun component_effect_path(group_name : string, key_name : string, name : string) : string
  state_slot/path(hook_named_effect_slot(component_local_path(group_name, key_name), name))

// Listener identity should be stable under conditional rendering, so unlike state hooks it is derived from
// a semantic name within the component scope instead of an index.

// Advanced integration hook: keeps a stable listener id while allowing callers
// that bridge an external protocol to give the action a separate semantic name.
// Normal component code should use `on_local_click` instead.
pub fun on_scoped_click<s,e::E>(scope_base : string, listener_name : string, semantic_name : string, action : (s) -> <div|e> s) : <listener_registry<s,e>,div> listener
  register_listener(named_listener_slot(scope_base, Click_event, listener_name), Click_registration(semantic_name, action))

pub fun on_local_click<s,e::E>(name : string, action : (s) -> <div|e> s) : <hook_scope,listener_registry<s,e>,div> listener
  register_listener(named_listener_slot(current_hook_scope_name(), Click_event, name), Click_registration(name, action))

pub fun on_local_input<s,e::E>(name : string, action : (string, s) -> <action_observation,local_state_read,local_state_write,div> s) : <hook_scope,listener_registry<s,e>,div> listener
  register_listener(named_listener_slot(current_hook_scope_name(), Input_event, name), Input_registration(name, action))

pub fun on_local_enter<s,e::E>(name : string, action : (s) -> <div|e> s) : <hook_scope,listener_registry<s,e>,div> listener
  register_listener(named_listener_slot(current_hook_scope_name(), Enter_event, name), Enter_registration(name, action))

// Common reducer-backed controls only emit a typed component action and leave
// the owner unchanged. These helpers keep that event plumbing out of views.
pub fun on_store_click<s,t,a,e::E>(name : string, binding : store_binding<t,a>, action : a) : <hook_scope,listener_registry<s,<action_observation,local_state_write|e>>,div> listener
  on_local_click(name, fn(owner) {
    binding.send.(action)
    owner
  })

pub fun on_store_input<s,t,a,e::E>(name : string, binding : store_binding<t,a>, action : (string) -> a) : <hook_scope,listener_registry<s,e>,div> listener
  on_local_input(name, fn(value, owner) {
    binding.send.(action(value))
    owner
  })

fun replace_registered_click<s,e::E>(items : list<registered_click<s,e>>, next_item : registered_click<s,e>) : <div> list<registered_click<s,e>>
  match items
    Nil -> [next_item]
    Cons(item, rest) -> if registered_click/id(item) == registered_click/id(next_item) then Cons(next_item, rest) else Cons(item, replace_registered_click(rest, next_item))

fun replace_registered_input<s>(items : list<registered_input<s>>, next_item : registered_input<s>) : <div> list<registered_input<s>>
  match items
    Nil -> [next_item]
    Cons(item, rest) -> if registered_input/id(item) == registered_input/id(next_item) then Cons(next_item, rest) else Cons(item, replace_registered_input(rest, next_item))

fun duplicate_listener_warning(handler_id : string, semantic_name : string) : string
  "Duplicate listener registration for `" ++ handler_id ++ "` (semantic `" ++ semantic_name ++ "`). The later registration replaced the earlier one."

fun semantic_drift_warning(handler_id : string, previous_semantic : string, next_semantic : string) : string
  "Listener semantic drift for `" ++ handler_id ++ "`: `" ++ previous_semantic ++ "` -> `" ++ next_semantic ++ "`. Consider using a new named listener or splitting the conditional branch."

pub fun run_event_registry<s,e::E,a>(action : () -> <listener_registry<s,e>,div> a) : <div> (a, event_registry<s,e>)
  var registered_clicks := Nil
  var registered_inputs := Nil
  var registry_warnings := Nil
  with return(result) (result, Event_registry(registered_clicks, registered_inputs, registry_warnings))
  with fun register_listener(entry_slot, registration) {
      val handler_id = state_slot/path(entry_slot)
      match registration
        Click_registration(semantic_name, callback) -> {
          match find_click_in_list(registered_clicks, handler_id)
            Just(found) -> {
              registry_warnings := Cons(if registered_click/semantic_name(found) == semantic_name then duplicate_listener_warning(handler_id, semantic_name) else semantic_drift_warning(handler_id, registered_click/semantic_name(found), semantic_name), registry_warnings)
              registered_clicks := replace_registered_click(registered_clicks, Registered_click(handler_id, semantic_name, callback))
              Listener(Click_event, handler_id)
            }
            Nothing -> {
              registered_clicks := append_registered_click(registered_clicks, Registered_click(handler_id, semantic_name, callback))
              Listener(Click_event, handler_id)
            }
        }
        Input_registration(semantic_name, callback) -> {
          match find_input_in_list(registered_inputs, handler_id)
            Just(found) -> {
              registry_warnings := Cons(if registered_input/semantic_name(found) == semantic_name then duplicate_listener_warning(handler_id, semantic_name) else semantic_drift_warning(handler_id, registered_input/semantic_name(found), semantic_name), registry_warnings)
              registered_inputs := replace_registered_input(registered_inputs, Registered_input(handler_id, semantic_name, callback))
              Listener(Input_event, handler_id)
            }
            Nothing -> {
              registered_inputs := append_registered_input(registered_inputs, Registered_input(handler_id, semantic_name, callback))
              Listener(Input_event, handler_id)
            }
        }
        Enter_registration(semantic_name, callback) -> {
          match find_click_in_list(registered_clicks, handler_id)
            Just(found) -> {
              registry_warnings := Cons(if registered_click/semantic_name(found) == semantic_name then duplicate_listener_warning(handler_id, semantic_name) else semantic_drift_warning(handler_id, registered_click/semantic_name(found), semantic_name), registry_warnings)
              registered_clicks := replace_registered_click(registered_clicks, Registered_click(handler_id, semantic_name, callback))
              Listener(Enter_event, handler_id)
            }
            Nothing -> {
              registered_clicks := append_registered_click(registered_clicks, Registered_click(handler_id, semantic_name, callback))
              Listener(Enter_event, handler_id)
            }
        }
  }
  action()

fun run_stateful_component_with_tree<s,e::E,a>(
  owner : s,
  tree : list<state_entry>,
  render : (s) -> <local_state_read,local_state_write,hook_effects,hook_scope,hook_state,listener_registry<s,e>,div> a
) : <div> (s, list<state_entry>, a, list<scheduled_effect>, event_registry<s,e>)
  val ((result, next_tree, pending_effects), handlers) = run_event_registry(fn() run_local_state(tree, fn() render(owner)))
  (owner, next_tree, result, pending_effects, handlers)

pub fun run_stateful_component<s,e::E,a>(
  owner : s,
  render : (s) -> <local_state_read,local_state_write,hook_effects,hook_scope,hook_state,listener_registry<s,e>,div> a
) : <component_runtime,div> (s, a, list<scheduled_effect>, event_registry<s,e>)
  val (current_owner, next_tree, result, pending_effects, handlers) = run_stateful_component_with_tree(owner, current_component_state_entries(), render)
  replace_component_state_entries(next_tree)
  (current_owner, result, pending_effects, handlers)

pub fun read_local_state(tree : list<state_entry>, action : () -> <local_state_read,div|e> a) : <div|e> a
  with fun use_named_state(entry_slot, codec, fallback) state_value(tree, entry_slot, fallback, codec)
  action()

pub fun current_component_state_entries() : <component_runtime,div> list<state_entry>
  get_component_state_entries()

pub fun replace_component_state_entries(tree : list<state_entry>) : <component_runtime,div> ()
  set_component_state_entries(tree)

fun clear_slot(entry_slot : state_slot) : <local_state_write,div> ()
  clear_local_state(state_slot/path(entry_slot))

fun find_state(tree : list<state_entry>, path : string) : <div> maybe<state_entry>
  match tree
    Nil -> Nothing
    Cons(item, rest) -> if state_entry/path(item) == path then Just(item) else find_state(rest, path)

fun assoc_entry(tree : list<state_entry>, next_entry : state_entry) : <div> list<state_entry>
  match tree
    Nil -> [next_entry]
    Cons(item, rest) ->
      if state_entry/path(item) == state_entry/path(next_entry) then
        Cons(next_entry, rest)
      else
        Cons(item, assoc_entry(rest, next_entry))

// State is keyed by stable component paths so more local UI state can move out of the main domain model later.
pub fun state_text(tree : list<state_entry>, path : string, fallback : string) : <div> string
  state_value(tree, State_slot(path), fallback)

pub fun state_flag(tree : list<state_entry>, path : string, fallback : bool) : <div> bool
  state_value(tree, State_slot(path), fallback)

pub fun assoc_text(tree : list<state_entry>, path : string, text : string) : <div> list<state_entry>
  assoc_slot_value(tree, State_slot(path), text)

pub fun assoc_flag(tree : list<state_entry>, path : string, flag : bool) : <div> list<state_entry>
  assoc_slot_value(tree, State_slot(path), flag)

pub fun clear_state(tree : list<state_entry>, path : string) : <div> list<state_entry>
  match tree
    Nil -> Nil
    Cons(item, rest) -> if state_entry/path(item) == path then rest else Cons(item, clear_state(rest, path))

fun chars_have_prefix(text : list<char>, prefix_chars : list<char>) : bool
  match prefix_chars
    Nil -> True
    Cons(prefix_head, prefix_rest) ->
      match text
        Cons(text_head, text_rest) -> text_head == prefix_head && chars_have_prefix(text_rest, prefix_rest)
        Nil -> False

fun path_in_branch(path : string, branch_path : string) : bool
  path == branch_path || chars_have_prefix(list(path), list(branch_path ++ "/"))

pub fun clear_state_branch(tree : list<state_entry>, branch_path : string) : <div> list<state_entry>
  match tree
    Nil -> Nil
    Cons(item, rest) ->
      if path_in_branch(state_entry/path(item), branch_path) then
        clear_state_branch(rest, branch_path)
      else
        Cons(item, clear_state_branch(rest, branch_path))

fun append_scheduled_effect(items : list<scheduled_effect>, item : scheduled_effect) : <div> list<scheduled_effect>
  match items
    Nil -> [item]
    Cons(head, rest) -> Cons(head, append_scheduled_effect(rest, item))

pub fun append_scheduled_effects(left : list<scheduled_effect>, right : list<scheduled_effect>) : <div> list<scheduled_effect>
  match left
    Nil -> right
    Cons(head, rest) -> Cons(head, append_scheduled_effects(rest, right))

pub fun compose_component_runs<s,e::E,a,b>(
  left : (s, a, list<scheduled_effect>, event_registry<s,e>),
  right : (s) -> <div> (s, b, list<scheduled_effect>, event_registry<s,e>)
) : <div> (s, (a, b), list<scheduled_effect>, event_registry<s,e>)
  val (next_owner, left_result, left_effects, left_handlers) = left
  val (final_owner, right_result, right_effects, right_handlers) = right(next_owner)
  (final_owner, (left_result, right_result), append_scheduled_effects(left_effects, right_effects), append_event_registries(left_handlers, right_handlers))

pub fun map_component_run<s,e::E,a,b,f::E>(
  item : (s, a, list<scheduled_effect>, event_registry<s,e>),
  transform : (s, a) -> <div|f> b
) : <div|f> (s, b, list<scheduled_effect>, event_registry<s,e>)
  val (owner, result, effects, handlers) = item
  (owner, transform(owner, result), effects, handlers)

fun effect_signature(deps : list<string>) : <div> string
  match deps
    Nil -> ""
    Cons(head, rest) ->
      if rest == Nil then head else head ++ "\u001f" ++ effect_signature(rest)

fun effect_entry(slot_item : state_slot, deps : list<string>) : <div> state_entry
  State_entry(state_slot/path(slot_item), "respo/effect", 1, effect_signature(deps))

pub fun count_entries(tree : list<state_entry>) : <div> int
  match tree
    Nil -> 0
    Cons(_, rest) -> 1 + count_entries(rest)

fun encode_snapshot_entry(entry : state_entry) : string
  snapshot_escape(entry.path) ++ "|" ++
  snapshot_escape(entry.schema) ++ "|" ++
  entry.version.show ++ "|" ++
  snapshot_escape(entry.payload)

fun append_snapshot_line(line : string, rest : string) : string
  if rest == "" then line else line ++ "\n" ++ rest

// Effect dependency signatures are render metadata. They are intentionally
// rebuilt after HMR instead of being persisted with component state.
pub fun encode_state_snapshot(tree : list<state_entry>) : <div> string
  match tree
    Nil -> ""
    Cons(entry, rest) ->
      val encoded_rest = encode_state_snapshot(rest)
      if entry.schema == "respo/effect" then encoded_rest
      else append_snapshot_line(encode_snapshot_entry(entry), encoded_rest)

fun decode_snapshot_entry(line : string) : maybe<state_entry>
  match split(line, "|")
    [encoded_path, encoded_schema, version, encoded_payload] -> {
      if not(snapshot_unescape_valid(encoded_path) && snapshot_unescape_valid(encoded_schema) && snapshot_unescape_valid(encoded_payload)) then Nothing
      else {
        val path = snapshot_unescape(encoded_path)
        val schema = snapshot_unescape(encoded_schema)
        if path == "" || schema == "" then Nothing
        else parse-int(version).map(fn(value) State_entry(path, schema, value, snapshot_unescape(encoded_payload)))
      }
    }
    _ -> Nothing

fun decode_snapshot_lines(lines : list<string>) : list<state_entry>
  match lines
    Nil -> Nil
    Cons(line, rest) ->
      match decode_snapshot_entry(line)
        Just(entry) -> Cons(entry, decode_snapshot_lines(rest))
        Nothing -> decode_snapshot_lines(rest)

pub fun decode_state_snapshot(snapshot : string) : list<state_entry>
  if snapshot == "" then Nil else decode_snapshot_lines(split(snapshot, "\n"))

fun require_hook_scope(scope_name : string, kind : string) : string
  scope_name

// Event callbacks only need to read and update the already-created runtime
// tree. Handling this at the runtime boundary keeps tree plumbing out of
// component callbacks and out of the business model.
pub fun run_local_action(tree : list<state_entry>, action : () -> <local_state_read,local_state_write,div|e> a) : <div|e> (a, list<state_entry>)
  var next_tree := tree
  with return(result) (result, next_tree)
  with fun use_named_state(entry_slot, codec, fallback) state_value(next_tree, entry_slot, fallback, codec)
  with handler
    fun set_named_state(entry_slot, codec, value) next_tree := assoc_slot_value(next_tree, entry_slot, value, codec)
    fun update_named_state(entry_slot, codec, fallback, update) {
      val current = state_value(next_tree, entry_slot, fallback, codec)
      next_tree := assoc_slot_value(next_tree, entry_slot, update(current), codec)
    }
    fun clear_local_state(path) next_tree := clear_state(next_tree, path)
  action()

pub fun run_local_state(tree : list<state_entry>, action : () -> <local_state_read,local_state_write,hook_effects,hook_scope,hook_state,div|e> a) : <div|e> (a, list<state_entry>, list<scheduled_effect>)
  var next_tree := tree
  var pending_effects := Nil
  var hook_stack : list<hook_frame> := Nil
  var current_hook_scope := ""
  var next_state_hook_index := 0
  var next_effect_hook_index := 0
  with return(result) (result, next_tree, pending_effects)
  with fun use_named_state(entry_slot, codec, fallback) state_value(next_tree, entry_slot, fallback, codec)
  with handler
    fun set_named_state(entry_slot, codec, value) next_tree := assoc_slot_value(next_tree, entry_slot, value, codec)
    fun update_named_state(entry_slot, codec, fallback, update) {
      val current = state_value(next_tree, entry_slot, fallback, codec)
      next_tree := assoc_slot_value(next_tree, entry_slot, update(current), codec)
    }
    fun clear_local_state(path) next_tree := clear_state(next_tree, path)
  with handler
    fun use_named_effect(effect_slot, deps, callback) {
      val next_entry = effect_entry(effect_slot, deps)
      val changed = match find_state(next_tree, state_slot/path(effect_slot))
        Just(found) -> found.schema != next_entry.schema || found.version != next_entry.version || found.payload != next_entry.payload
        Nothing -> True
      next_tree := assoc_entry(next_tree, next_entry)
      if changed then pending_effects := append_scheduled_effect(pending_effects, Scheduled_effect(state_slot/path(effect_slot), callback)) else ()
    }
    fun use_effect(deps, callback) {
      val scope_name = require_hook_scope(current_hook_scope, "use_effect")
      val effect_slot = hook_effect_slot(scope_name, next_effect_hook_index)
      next_effect_hook_index := next_effect_hook_index + 1
      val next_entry = effect_entry(effect_slot, deps)
      val changed = match find_state(next_tree, state_slot/path(effect_slot))
        Just(found) -> found.schema != next_entry.schema || found.version != next_entry.version || found.payload != next_entry.payload
        Nothing -> True
      next_tree := assoc_entry(next_tree, next_entry)
      if changed then pending_effects := append_scheduled_effect(pending_effects, Scheduled_effect(state_slot/path(effect_slot), callback)) else ()
    }
  with handler
    fun current_hook_scope_name() current_hook_scope
    fun push_hook_scope(scope_name) {
      hook_stack := Cons(Hook_frame(current_hook_scope, next_state_hook_index, next_effect_hook_index), hook_stack)
      current_hook_scope := scope_name
      next_state_hook_index := 0
      next_effect_hook_index := 0
    }
    fun pop_hook_scope() {
      match hook_stack
        Nil -> ()
        Cons(frame, rest) -> {
          hook_stack := rest
          match frame
            Hook_frame(scope_name, state_index, effect_index) -> {
              current_hook_scope := scope_name
              next_state_hook_index := state_index
              next_effect_hook_index := effect_index
            }
        }
    }
  with handler
    fun use_state(fallback, ?state_codec) {
      val scope_name = require_hook_scope(current_hook_scope, "use_state")
      val entry_slot = hook_state_slot(scope_name, next_state_hook_index)
      next_state_hook_index := next_state_hook_index + 1
      state_value(next_tree, entry_slot, fallback, state_codec)
    }
    fun use_state_pair(fallback, ?state_codec) {
      val scope_name = require_hook_scope(current_hook_scope, "use_state_pair")
      val entry_slot = hook_state_slot(scope_name, next_state_hook_index)
      next_state_hook_index := next_state_hook_index + 1
      (state_value(next_tree, entry_slot, fallback, state_codec), fn(value) set_named_state(entry_slot, state_codec, value))
    }
  action()
