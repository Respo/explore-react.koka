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
  fun push_feature_scope(group_name : string, key_name : string) : ()
  fun pop_hook_scope() : ()
  fun current_hook_scope_name() : string
  fun resolve_feature_key(default_key : string) : string
  fun resolve_feature_marker(name : string, default_key : string) : string

pub effect component_runtime
  fun get_component_state_entries() : list<state_entry>
  fun set_component_state_entries(tree : list<state_entry>) : ()

pub effect hook_state
  fun use_state<a>(fallback : a, ?state_codec : state_codec<a>) : a
  fun use_state_pair<a>(fallback : a, ?state_codec : state_codec<a>) : (a, (a) -> <local_state_write,div> ())

pub effect listener_registry<s,e::E>
  fun register_listener(entry_slot : state_slot, registration : listener_registration<s,e>) : listener

// The complete capability row available while rendering a stateful component.
// Applications can bind this once to their owner and host effects instead of
// repeating framework internals in every component signature.
pub alias component_effect<s,e::E> = <hook_scope,hook_state,local_state_read,local_state_write,hook_effects,listener_registry<s,e>,div>

pub type listener_registration<s,e::E>
  Click_registration(semantic_name : string, run : (s) -> <div|e> s)
  Input_registration(semantic_name : string, run : (string, s) -> <div|e> s)
  Enter_registration(semantic_name : string, run : (s) -> <div|e> s)

pub struct state_slot(path : string)

// The runtime tree is deliberately type-erased, but every cell keeps enough
// schema information to be decoded by newer code after a hot reload.
pub struct state_codec<a>(schema : string, version : int, decode : (int, string) -> maybe<a>, encode : (a) -> string)

pub struct state_entry(path : string, schema : string, version : int, payload : string)

// A component store keeps state and actions typed inside business code. Only
// state entries and action messages cross the type-erased runtime boundary.
pub struct store_spec<s,a>(name : string, state_codec : state_codec<s>, action_codec : action_codec<a>, reduce : (s, a) -> s)
pub alias store_dispatch<a> = (a) -> <action_observation,local_state_write,div> ()

inline extern snapshot_escape(text : string) : string
  js inline "encodeURIComponent(#1)"

inline extern snapshot_unescape(text : string) : string
  js inline "((s) => { try { return decodeURIComponent(s); } catch (_) { return ''; } })(#1)"

inline extern snapshot_unescape_valid(text : string) : bool
  js inline "((s) => { try { decodeURIComponent(s); return true; } catch (_) { return false; } })(#1)"

pub struct scheduled_effect(path : string, run : () -> io ())
pub struct registered_click<s,e::E>(id : string, semantic_name : string, run : (s) -> <div|e> s)
pub struct registered_input<s,e::E>(id : string, semantic_name : string, run : (string, s) -> <div|e> s)
pub struct event_registry<s,e::E>(clicks : list<registered_click<s,e>>, inputs : list<registered_input<s,e>>, warnings : list<string>)
struct hook_frame(
  scope_name : string,
  next_state_index : int,
  next_effect_index : int,
  feature_group_name : string,
  feature_key_name : string)

fun state_codec_read(item : state_codec<a>, entry : state_entry) : maybe<a>
  item.decode.(entry.version, entry.payload)

fun state_codec_write(item : state_codec<a>, path : string, value : a) : state_entry
  State_entry(path, item.schema, item.version, item.encode.(value))

fun join_slot_path(base : string, name : string) : string
  if base == "" then name else base ++ "/" ++ name

fun normalize_slot_name(name : string) : string
  val encoded = snapshot_escape(name)
  match list(name)
    Nil -> "__"
    Cons(head, _rest) ->
      if head >= '0' && head <= '9' then "_" ++ encoded
      else if head == '_' then "__" ++ encoded
      else encoded

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
  schema = "respo/string",
  version = 1,
  decode = fn(version, payload) if version == 1 then Just(payload) else Nothing,
  encode = fn(value) value)

pub val bool/state_codec : state_codec<bool> = State_codec(
  schema = "respo/bool",
  version = 1,
  decode = fn(version, payload) {
    if version != 1 then Nothing
    else if payload == "true" then Just(True)
    else if payload == "false" then Just(False)
    else Nothing
  },
  encode = fn(value) if value then "true" else "false")

pub fun run_registered_click<s,e::E>(item : registered_click<s,e>, owner : s) : <div|e> s
  item.run.(owner)

pub fun run_registered_input<s,e::E>(item : registered_input<s,e>, value : string, owner : s) : <div|e> s
  item.run.(value, owner)

pub fun empty_event_registry<s,e::E>() : event_registry<s,e>
  Event_registry(Nil, Nil, Nil)

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

fun append_registered_input<s,e::E>(items : list<registered_input<s,e>>, item : registered_input<s,e>) : <div> list<registered_input<s,e>>
  match items
    Nil -> [item]
    Cons(head, rest) -> Cons(head, append_registered_input(rest, item))

fun append_messages(left : list<string>, right : list<string>) : <div> list<string>
  match left
    Nil -> right
    Cons(head, rest) -> Cons(head, append_messages(rest, right))

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

pub fun find_registered_input<s,e::E>(registry : event_registry<s,e>, target_id : string) : <div> maybe<registered_input<s,e>>
  find_input_in_list(event_registry/inputs(registry), target_id)

fun find_input_in_list<s,e::E>(items : list<registered_input<s,e>>, target_id : string) : <div> maybe<registered_input<s,e>>
  match items
    Nil -> Nothing
    Cons(item, rest) -> if registered_input/id(item) == target_id then Just(item) else find_input_in_list(rest, target_id)

// Find the first registered input whose semantic name matches.
pub fun find_registered_input_by_semantic<s,e::E>(registry : event_registry<s,e>, semantic : string) : <div> maybe<registered_input<s,e>>
  find_input_by_semantic_in_list(event_registry/inputs(registry), semantic)

fun find_input_by_semantic_in_list<s,e::E>(items : list<registered_input<s,e>>, semantic : string) : <div> maybe<registered_input<s,e>>
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

fun count_input_items<s,e::E>(items : list<registered_input<s,e>>) : <div> int
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

fun compare_input_semantics<s,e::E>(previous : list<registered_input<s,e>>, next : list<registered_input<s,e>>) : <div> list<string>
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

fun use_named_state_pair(entry_slot : state_slot, fallback : a, ?state_codec : state_codec<a>) : <local_state_read,div> (a, (a) -> <local_state_write,div> ())
  (use_named_state(entry_slot, state_codec, fallback), fn(value) set_named_state(entry_slot, state_codec, value))

// React-like hook helpers: `component(...)` declares one stable keyed child,
// and plain `use_state(...)` / `use_effect(...)` then consume numbered slots automatically.
// Raw scope-path handling remains private to the framework.

fun with_hook_scope(scope_name : string, action : () -> <hook_scope|e> a) : <hook_scope|e> a
  push_hook_scope(scope_name)
  val result = action()
  pop_hook_scope()
  result

fun component_at(scope_name : string, render : () -> <hook_scope|e> a) : <hook_scope|e> a
  with_hook_scope(scope_name, render)

fun with_feature_scope(group : string, key : string, action : () -> <hook_scope|e> a) : <hook_scope|e> a
  push_feature_scope(group, key)
  val result = action()
  pop_hook_scope()
  result

// A feature root has absolute identity, so its state can survive layout moves,
// temporary unmounts, and hot replacement. Public feature components should
// expose their key when more than one instance can appear in the same tree.
pub fun feature_root(group : string, key : string, render : () -> <hook_scope|e> a) : <hook_scope|e> a
  with_feature_scope(group, key, render)

// A feature's persistent runtime key and its sibling VDOM key serve different
// jobs. Keep the historical singleton VDOM key for the default instance while
// deriving a unique one for additional instances.
pub fun feature_node_key(group : string, key : string, default_key : string = "panel") : string
  val group_name = normalize_slot_name(group)
  if key == default_key then group_name else group_name ++ ":" ++ normalize_slot_name(key)

// DOM effects query by marker, so repeated feature instances need the same key
// discipline as stores and listeners. The default instance keeps legacy marker
// names to preserve browser behavior and existing snapshots/tests.
pub fun feature_dom_marker(group : string, key : string, name : string, default_key : string = "panel") : string
  val marker_name = normalize_slot_name(name)
  if key == default_key then marker_name else feature_node_key(group, key, default_key) ++ ":" ++ marker_name

// Business components already declare their stable identity at `feature_root`.
// Descendants can derive VDOM keys and DOM markers from that boundary instead
// of forwarding the same `key` prop through every helper component.
pub fun feature_key(default_key : string = "panel") : <hook_scope,div> string
  resolve_feature_key(default_key)

pub fun feature_marker(name : string, default_key : string = "panel") : <hook_scope,div> string
  resolve_feature_marker(name, default_key)

// A normal keyed child component is relative to its current parent scope.
pub fun component(group : string, key : string, render : () -> <hook_scope|e> a) : <hook_scope|e> a
  component_at(child_scope(current_hook_scope_name(), group, key), render)

// Render a keyed collection of child components without exposing scope-path
// construction or repeating a one-line `map(... component(...))` helper.
pub fun components<a,e>(
  items : list<a>,
  group : string,
  key : (a) -> string,
  render : (a) -> <hook_scope|e> vnode
) : <hook_scope|e> list<vnode>
  map(items, fn(item) component(group, key(item)) { render(item) })

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

// Reducer-backed local state follows the familiar `(state, dispatch)` shape.
// Action observation stays inside dispatch, so component definitions keep the
// familiar reducer pair without exposing a framework-specific binding record.
pub fun use_store<s,a>(spec : store_spec<s,a>, initial : s) : <hook_scope,local_state_read,div> (s, store_dispatch<a>)
  val scope = current_hook_scope_name()
  val entry_slot = local_named_state_slot(spec.name)
  val codec = spec.state_codec
  val current = use_named_state(entry_slot, codec, initial)
  (current, fn(action) {
    emit_action(source = "component", target = scope, codec = spec.action_codec, action = action)
    update_named_state(entry_slot, codec, initial, fn(latest) spec.reduce.(latest, action))
  })

pub fun encode_store_action<s,a>(target : string, spec : store_spec<s,a>, action : a) : action_envelope
  encode_action(source = "component", target = target, codec = spec.action_codec, action = action)

pub fun decode_store_action<s,a>(spec : store_spec<s,a>, message : action_envelope) : maybe<a>
  if message.source != "component" then Nothing
  else decode_action(spec.action_codec, message)

pub fun read_store_state<s,a>(tree : list<state_entry>, scope_name : string, spec : store_spec<s,a>, initial : s) : <div> s
  read_named_local_state(tree, scope_name, spec.name, initial, spec.state_codec)

pub fun state_effect(name : string, deps : list<string>, action : () -> io ()) : <hook_scope,hook_effects,div> ()
  use_named_effect(local_named_effect_slot(name), deps, action)

// Stable paths are exposed for runtime inspection and tests. Business reducers
// do not use them to reach into a child component's store.
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

pub fun component_listener_path(group_name : string, key_name : string, kind : dom_event_kind, name : string) : string
  state_slot/path(named_listener_slot(component_local_path(group_name, key_name), kind, name))

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

pub fun on_local_input<s,e::E>(name : string, action : (string, s) -> <div|e> s) : <hook_scope,listener_registry<s,e>,div> listener
  register_listener(named_listener_slot(current_hook_scope_name(), Input_event, name), Input_registration(name, action))

pub fun on_local_enter<s,e::E>(name : string, action : (s) -> <div|e> s) : <hook_scope,listener_registry<s,e>,div> listener
  register_listener(named_listener_slot(current_hook_scope_name(), Enter_event, name), Enter_registration(name, action))

// Domain actions should stay visible at component call sites without repeating
// the closure that only forwards an action and the current owner to a reducer.
pub fun on_action_click<s,a,e::E>(name : string, action : a, dispatch : (a, s) -> <div|e> s) : <hook_scope,listener_registry<s,e>,div> listener
  on_local_click(name, fn(owner) dispatch(action, owner))

pub fun on_action_enter<s,a,e::E>(name : string, action : a, dispatch : (a, s) -> <div|e> s) : <hook_scope,listener_registry<s,e>,div> listener
  on_local_enter(name, fn(owner) dispatch(action, owner))

pub fun on_action_input<s,a,e::E>(name : string, action : (string) -> a, dispatch : (a, s) -> <div|e> s) : <hook_scope,listener_registry<s,e>,div> listener
  on_local_input(name, fn(value, owner) dispatch(action(value), owner))

// Common reducer-backed controls only emit a typed component action and leave
// the owner unchanged. These helpers keep that event plumbing out of views.
pub fun on_store_click<s,a,e::E>(name : string, action : a, dispatch : store_dispatch<a>) : <hook_scope,listener_registry<s,<action_observation,local_state_write|e>>,div> listener
  on_local_click(name, fn(owner) {
    dispatch(action)
    owner
  })

pub fun on_store_input<s,a,e::E>(name : string, action : (string) -> a, dispatch : store_dispatch<a>) : <hook_scope,listener_registry<s,<action_observation,local_state_write|e>>,div> listener
  on_local_input(name, fn(value, owner) {
    dispatch(action(value))
    owner
  })

fun replace_registered_click<s,e::E>(items : list<registered_click<s,e>>, next_item : registered_click<s,e>) : <div> list<registered_click<s,e>>
  match items
    Nil -> [next_item]
    Cons(item, rest) -> if registered_click/id(item) == registered_click/id(next_item) then Cons(next_item, rest) else Cons(item, replace_registered_click(rest, next_item))

fun replace_registered_input<s,e::E>(items : list<registered_input<s,e>>, next_item : registered_input<s,e>) : <div> list<registered_input<s,e>>
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

// App integration normally needs one stable root scope around a stateful
// component. Callers label identity and render so the boundary stays
// self-describing instead of exposing nested runtime plumbing.
pub fun run_component<s,e::E,a>(
  owner : s,
  group : string,
  key : string,
  render : (s) -> <local_state_read,local_state_write,hook_effects,hook_scope,hook_state,listener_registry<s,e>,div> a
) : <component_runtime,div> (s, a, list<scheduled_effect>, event_registry<s,e>)
  run_stateful_component(owner) fn(current)
    feature_root(group, key) { render(current) }

pub fun read_local_state(tree : list<state_entry>, action : () -> <local_state_read,div|e> a) : <div|e> a
  with fun use_named_state(entry_slot, codec, fallback) state_value(tree, entry_slot, fallback, codec)
  action()

fun current_component_state_entries() : <component_runtime,div> list<state_entry>
  get_component_state_entries()

fun replace_component_state_entries(tree : list<state_entry>) : <component_runtime,div> ()
  set_component_state_entries(tree)

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

fun clear_state_branch(tree : list<state_entry>, branch_path : string) : <div> list<state_entry>
  match tree
    Nil -> Nil
    Cons(item, rest) ->
      if path_in_branch(state_entry/path(item), branch_path) then
        clear_state_branch(rest, branch_path)
      else
        Cons(item, clear_state_branch(rest, branch_path))

// Reset a persistent feature instance without exposing runtime tree paths to
// business lifecycle code.
pub fun reset_feature(group : string, key : string) : <component_runtime,div> ()
  replace_component_state_entries(clear_state_branch(current_component_state_entries(), component_local_path(group, key)))

fun append_scheduled_effect(items : list<scheduled_effect>, item : scheduled_effect) : <div> list<scheduled_effect>
  match items
    Nil -> [item]
    Cons(head, rest) -> Cons(head, append_scheduled_effect(rest, item))

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
  var current_feature_group := ""
  var current_feature_key := ""
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
    fun resolve_feature_key(default_key) feature_node_key(current_feature_group, current_feature_key, default_key)
    fun resolve_feature_marker(name, default_key) feature_dom_marker(current_feature_group, current_feature_key, name, default_key)
    fun push_hook_scope(scope_name) {
      hook_stack := Cons(Hook_frame(
        current_hook_scope,
        next_state_hook_index,
        next_effect_hook_index,
        current_feature_group,
        current_feature_key), hook_stack)
      current_hook_scope := scope_name
      next_state_hook_index := 0
      next_effect_hook_index := 0
    }
    fun push_feature_scope(group_name, key_name) {
      hook_stack := Cons(Hook_frame(
        current_hook_scope,
        next_state_hook_index,
        next_effect_hook_index,
        current_feature_group,
        current_feature_key), hook_stack)
      current_hook_scope := component_local_path(group_name, key_name)
      current_feature_group := group_name
      current_feature_key := key_name
      next_state_hook_index := 0
      next_effect_hook_index := 0
    }
    fun pop_hook_scope() {
      match hook_stack
        Nil -> ()
        Cons(frame, rest) -> {
          hook_stack := rest
          match frame
            Hook_frame(scope_name, state_index, effect_index, feature_group_name, feature_key_name) -> {
              current_hook_scope := scope_name
              current_feature_group := feature_group_name
              current_feature_key := feature_key_name
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
