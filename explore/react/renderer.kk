module explore/react/renderer

import runtime/dom
import explore/react/core

fun attr_eq(left : attr, right : attr) : bool
  attr/name(left) == attr/name(right) && attr/value(left) == attr/value(right)

fun listener_eq(left : listener, right : listener) : bool
  dom_event_kind_name(listener/kind(left)) == dom_event_kind_name(listener/kind(right)) && listener/payload(left) == listener/payload(right)

fun find_attr(attrs : list<attr>, target_name : string) : <div> maybe<attr>
  match attrs
    Nil -> Nothing
    Cons(item, rest) -> if attr/name(item) == target_name then Just(item) else find_attr(rest, target_name)

fun attrs_eq(left : list<attr>, right : list<attr>) : <div> bool
  match left
    Nil ->
      match right
        Nil -> True
        _ -> False
    Cons(lx, lxs) ->
      match right
        Cons(rx, rxs) -> attr_eq(lx, rx) && attrs_eq(lxs, rxs)
        _ -> False

fun listeners_eq(left : list<listener>, right : list<listener>) : <div> bool
  match left
    Nil ->
      match right
        Nil -> True
        _ -> False
    Cons(lx, lxs) ->
      match right
        Cons(rx, rxs) -> listener_eq(lx, rx) && listeners_eq(lxs, rxs)
        _ -> False

fun child_keys_eq(left : list<vnode>, right : list<vnode>) : <div> bool
  match left
    Nil ->
      match right
        Nil -> True
        _ -> False
    Cons(lx, lxs) ->
      match right
        Cons(rx, rxs) -> vnode/key(lx) == vnode/key(rx) && child_keys_eq(lxs, rxs)
        _ -> False

fun join_path(path : string, index : int) : string
  path ++ "." ++ index.show

fun render_attrs(attrs : list<attr>) : <div> string
  match attrs
    Nil -> ""
    Cons(item, rest) -> " " ++ attr/name(item) ++ "=\"" ++ html_escape(attr/value(item)) ++ "\"" ++ render_attrs(rest)

fun render_listeners(listeners : list<listener>) : <div> string
  match listeners
    Nil -> ""
    Cons(item, rest) ->
      match listener/kind(item)
        Click_event -> " data-k-click=\"" ++ html_escape(listener/payload(item)) ++ "\"" ++ render_listeners(rest)
        Input_event -> " data-k-input=\"" ++ html_escape(listener/payload(item)) ++ "\"" ++ render_listeners(rest)
        Enter_event -> " data-k-enter=\"" ++ html_escape(listener/payload(item)) ++ "\"" ++ render_listeners(rest)

fun render_children(path : string, index : int, children : list<vnode>) : <div> string
  match children
    Nil -> ""
    Cons(child, rest) -> render_node(join_path(path, index), child) ++ render_children(path, index + 1, rest)

// Render a VDOM subtree into deterministic HTML so that tests and patching stay stable.
pub fun render_node(path : string, node : vnode) : <div> string
  val path_attr = Attr("data-kpath", path)
  val open_tag = "<" ++ vnode/tag(node) ++ render_attrs(Cons(path_attr, vnode/attrs(node))) ++ render_listeners(vnode/listeners(node))
  if vnode/tag(node) == "input" then
    open_tag ++ " />"
  else
    open_tag ++ ">" ++ html_escape(vnode/text(node)) ++ render_children(path, 0, vnode/children(node)) ++ "</" ++ vnode/tag(node) ++ ">"

fun replace_patch(path : string, node : vnode) : <div> list<patch>
  [Patch(path, "replace", "", "", render_node(path, node))]

fun set_attr_patch(path : string, name : string, value : string) : list<patch>
  [Patch(path, "set-attr", name, value, "")]

fun clear_attr_patch(path : string, name : string) : list<patch>
  [Patch(path, "clear-attr", name, "", "")]

fun append_patches(left : list<patch>, right : list<patch>) : <div> list<patch>
  match left
    Nil -> right
    Cons(item, rest) -> Cons(item, append_patches(rest, right))

fun diff_set_attr_patches(path : string, previous : list<attr>, next : list<attr>) : <div> list<patch>
  match next
    Nil -> Nil
    Cons(item, rest) ->
      val tail = diff_set_attr_patches(path, previous, rest)
      match find_attr(previous, attr/name(item))
        Just(found) -> if attr/value(found) == attr/value(item) then tail else append_patches(set_attr_patch(path, attr/name(item), attr/value(item)), tail)
        Nothing -> append_patches(set_attr_patch(path, attr/name(item), attr/value(item)), tail)

fun diff_clear_attr_patches(path : string, previous : list<attr>, next : list<attr>) : <div> list<patch>
  match previous
    Nil -> Nil
    Cons(item, rest) ->
      val tail = diff_clear_attr_patches(path, rest, next)
      match find_attr(next, attr/name(item))
        Just(_) -> tail
        Nothing -> append_patches(clear_attr_patch(path, attr/name(item)), tail)

fun diff_attr_patches(path : string, previous : list<attr>, next : list<attr>) : <div> list<patch>
  append_patches(diff_set_attr_patches(path, previous, next), diff_clear_attr_patches(path, previous, next))

fun diff_children(path : string, index : int, left : list<vnode>, right : list<vnode>) : <div> list<patch>
  match left
    Nil -> Nil
    Cons(lx, lxs) ->
      match right
        Cons(rx, rxs) -> append_patches(diff_node(join_path(path, index), lx, rx), diff_children(path, index + 1, lxs, rxs))
        _ -> Nil

// The initial diff strategy is intentionally small: if tags/keys/attrs/listeners/text differ,
// replace that subtree. This keeps the core readable before pursuing finer-grained patches.
pub fun diff_node(path : string, previous : vnode, next : vnode) : <div> list<patch>
  if vnode/tag(previous) != vnode/tag(next) then replace_patch(path, next)
  else if vnode/key(previous) != vnode/key(next) then replace_patch(path, next)
  else if not(listeners_eq(vnode/listeners(previous), vnode/listeners(next))) then replace_patch(path, next)
  else if vnode/text(previous) != vnode/text(next) then replace_patch(path, next)
  else if not(child_keys_eq(vnode/children(previous), vnode/children(next))) then replace_patch(path, next)
  else append_patches(diff_attr_patches(path, vnode/attrs(previous), vnode/attrs(next)), diff_children(path, 0, vnode/children(previous), vnode/children(next)))

// Apply previously computed patches through the DOM bridge. The browser remains the only imperative surface.
pub fun apply_patches(root_id : string, patches : list<patch>) : <div,io> ()
  match patches
    Nil -> ()
    Cons(item, rest) ->
      if patch/kind(item) == "replace" then
        patch_html(root_id, patch/path(item), patch/html(item))
      else if patch/kind(item) == "set-attr" then
        patch_attr(root_id, patch/path(item), patch/name(item), patch/value(item))
      else if patch/kind(item) == "clear-attr" then
        clear_attr(root_id, patch/path(item), patch/name(item))
      else
        ()
      apply_patches(root_id, rest)
