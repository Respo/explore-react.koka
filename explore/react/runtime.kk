module explore/react/runtime

import explore/react/state

// Host execution and snapshot transport stay outside the component-authoring
// import path. The runtime works with opaque state entries and registered typed
// callbacks; business views never call these functions.

pub fun run_registered_click<s,e::E>(item : registered_click<s,e>, owner : s) : <div|e> s
  item.run.(owner)

pub fun run_registered_input<s,e::E>(item : registered_input<s,e>, value : string, owner : s) : <div|e> s
  item.run.(value, owner)

pub fun empty_event_registry<s,e::E>() : event_registry<s,e>
  Event_registry(Nil, Nil, Nil)

pub struct registered_effect(path : string, cleanup : () -> io ())

pub fun empty_effect_registry() : list<registered_effect>
  Nil

fun remove_registered_effect(items : list<registered_effect>, path : string) : list<registered_effect>
  match items
    Nil -> Nil
    Cons(item, rest) ->
      if registered_effect/path(item) == path then rest
      else Cons(item, remove_registered_effect(rest, path))

fun find_registered_effect(items : list<registered_effect>, path : string) : maybe<registered_effect>
  match items
    Nil -> Nothing
    Cons(item, rest) -> if registered_effect/path(item) == path then Just(item) else find_registered_effect(rest, path)

fun run_cleanup_safely(action : () -> io ()) : io string
  try(
    fn() {
      action()
      ""
    },
    fn(problem) problem.message)

fun cleanup_registered_effect(
  registry : list<registered_effect>,
  path : string,
  on_error : (string) -> io ()
) : io list<registered_effect>
  match find_registered_effect(registry, path)
    Nothing -> registry
    Just(found) -> {
      val message = run_cleanup_safely(registered_effect/cleanup(found))
      if message != "" then on_error("Cleanup failed for `" ++ path ++ "`: " ++ message) else ()
      remove_registered_effect(registry, path)
    }

// A changed dependency always releases the previous resource before setup.
// Cleanup failures are reported but cannot block the next setup or HMR boot.
pub fun run_scheduled_effect(
  registry : list<registered_effect>,
  item : scheduled_effect,
  on_error : (string) -> io ()
) : io list<registered_effect>
  val next_registry = cleanup_registered_effect(registry, scheduled_effect/path(item), on_error)
  match scheduled_effect/kind(item)
    Effect_cleanup -> next_registry
    Effect_install -> {
      scheduled_effect/run(item).()
      Cons(Registered_effect(scheduled_effect/path(item), scheduled_effect/cleanup(item)), next_registry)
    }

pub fun dispose_effect_registry(
  registry : list<registered_effect>,
  on_error : (string) -> io ()
) : io list<registered_effect>
  match registry
    Nil -> Nil
    Cons(item, rest) -> {
      val message = run_cleanup_safely(registered_effect/cleanup(item))
      if message != "" then on_error("Cleanup failed for `" ++ registered_effect/path(item) ++ "`: " ++ message) else ()
      dispose_effect_registry(rest, on_error)
    }

inline extern runtime_snapshot_escape(text : string) : string
  js inline "encodeURIComponent(#1)"

inline extern runtime_snapshot_unescape(text : string) : string
  js inline "((s) => { try { return decodeURIComponent(s); } catch (_) { return ''; } })(#1)"

inline extern runtime_snapshot_unescape_valid(text : string) : bool
  js inline "((s) => { try { decodeURIComponent(s); return true; } catch (_) { return false; } })(#1)"

val runtime_snapshot_marker = "respo/runtime-snapshot"
val runtime_snapshot_version = 1

fun encode_snapshot_entry(entry : state_entry) : string
  runtime_snapshot_escape(entry.path) ++ "|" ++
  runtime_snapshot_escape(entry.schema) ++ "|" ++
  entry.version.show ++ "|" ++
  runtime_snapshot_escape(entry.payload)

fun append_snapshot_line(line : string, rest : string) : string
  if rest == "" then line else line ++ "\n" ++ rest

// Effect dependency signatures are render metadata. They are intentionally
// rebuilt after HMR instead of being persisted with component state.
fun encode_snapshot_entries(tree : list<state_entry>) : <div> string
  match tree
    Nil -> ""
    Cons(entry, rest) ->
      val encoded_rest = encode_snapshot_entries(rest)
      if entry.schema == "respo/effect" then encoded_rest
      else append_snapshot_line(encode_snapshot_entry(entry), encoded_rest)

pub fun encode_state_snapshot(tree : list<state_entry>) : <div> string
  append_snapshot_line(runtime_snapshot_marker ++ "|" ++ runtime_snapshot_version.show, encode_snapshot_entries(tree))

fun decode_snapshot_entry(line : string) : maybe<state_entry>
  match split(line, "|")
    [encoded_path, encoded_schema, version, encoded_payload] -> {
      if not(runtime_snapshot_unescape_valid(encoded_path) && runtime_snapshot_unescape_valid(encoded_schema) && runtime_snapshot_unescape_valid(encoded_payload)) then Nothing
      else {
        val path = runtime_snapshot_unescape(encoded_path)
        val schema = runtime_snapshot_unescape(encoded_schema)
        if path == "" || schema == "" then Nothing
        else parse-int(version).map(fn(value) State_entry(path, schema, value, runtime_snapshot_unescape(encoded_payload)))
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
  if snapshot == "" then Nil
  else match split(snapshot, "\n")
    Nil -> Nil
    Cons(header, entries) ->
      match split(header, "|")
        Cons(marker, version_parts) ->
          if marker != runtime_snapshot_marker then decode_snapshot_lines(Cons(header, entries))
          else match version_parts
            [version] -> match parse-int(version)
              Just(value) -> if value == runtime_snapshot_version then decode_snapshot_lines(entries) else Nil
              Nothing -> Nil
            _ -> Nil
        Nil -> decode_snapshot_lines(Cons(header, entries))
