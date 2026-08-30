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

pub fun run_scheduled_effect(item : scheduled_effect) : io ()
  item.run.()

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
