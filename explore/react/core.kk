module explore/react/core

pub type dom_event_kind
  Click_event
  Input_event
  Enter_event

pub struct attr(name : string, value : string)
pub struct listener(kind : dom_event_kind, payload : string)
pub struct vnode(tag : string, key : string, attrs : list<attr>, listeners : list<listener>, text : string, children : list<vnode>)
pub struct patch(path : string, kind : string, name : string, value : string, html : string)

pub fun dom_event_kind_name(kind : dom_event_kind) : string
  match kind
    Click_event -> "click"
    Input_event -> "input"
    Enter_event -> "enter"

fun prepend_text_attr(name : string, value : string, tail : list<attr>) : list<attr>
  if value == "" then tail else Cons(Attr(name, value), tail)

fun prepend_listener(item : listener, tail : list<listener>) : list<listener>
  if listener/payload(item) == "" then tail else Cons(item, tail)

fun element_attrs(class : string, id : string, data_effect : string, extra_attrs : list<attr>) : list<attr>
  val with_effect = prepend_text_attr("data-k-effect", data_effect, extra_attrs)
  val with_id = prepend_text_attr("id", id, with_effect)
  prepend_text_attr("class", class, with_id)

fun element_events(click : listener, input : listener, enter : listener, extra_events : list<listener>) : list<listener>
  val with_enter = prepend_listener(enter, extra_events)
  val with_input = prepend_listener(input, with_enter)
  prepend_listener(click, with_input)

fun no_click() : listener
  Listener(Click_event, "")

fun no_input() : listener
  Listener(Input_event, "")

fun no_enter() : listener
  Listener(Enter_event, "")

// Construct a keyed VDOM node that can later be diffed and patched.
// Keep `key` stable among siblings; feature code should usually build nodes through `el(...)` and higher-level state/event helpers.
pub fun el(tag : string, key : string, attrs : list<attr>, listeners : list<listener>, text : string, children : list<vnode>) : vnode
  Vnode(tag, key, attrs, listeners, text, children)

// Element helpers keep their primary content positional. Common DOM attributes and
// events are flat labelled arguments; uncommon values use the two `extra_*` escape hatches.
pub fun div(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("div", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun section(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("section", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun article(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("article", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun aside(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("aside", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun header(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("header", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun nav(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("nav", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun ul(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("ul", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun li(children : list<vnode>, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("li", key, element_attrs(class, id, data_effect, extra_attrs), Nil, "", children)

pub fun li_text(text : string, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("li", key, element_attrs(class, id, data_effect, extra_attrs), Nil, text, Nil)

pub fun span(text : string, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("span", key, element_attrs(class, id, data_effect, extra_attrs), Nil, text, Nil)

pub fun strong(text : string, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("strong", key, element_attrs(class, id, data_effect, extra_attrs), Nil, text, Nil)

pub fun p(text : string, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("p", key, element_attrs(class, id, data_effect, extra_attrs), Nil, text, Nil)

pub fun h1(text : string, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("h1", key, element_attrs(class, id, data_effect, extra_attrs), Nil, text, Nil)

pub fun h2(text : string, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("h2", key, element_attrs(class, id, data_effect, extra_attrs), Nil, text, Nil)

pub fun h3(text : string, class : string = "", key : string = "", id : string = "", data_effect : string = "", extra_attrs : list<attr> = Nil) : vnode
  el("h3", key, element_attrs(class, id, data_effect, extra_attrs), Nil, text, Nil)

pub fun button(
  text : string,
  class : string = "",
  key : string = "",
  id : string = "",
  data_effect : string = "",
  click : listener = no_click(),
  enter : listener = no_enter(),
  extra_attrs : list<attr> = Nil,
  extra_events : list<listener> = Nil
) : vnode
  el("button", key, element_attrs(class, id, data_effect, extra_attrs), element_events(click, no_input(), enter, extra_events), text, Nil)

pub fun input(
  value : string = "",
  placeholder : string = "",
  input_type : string = "text",
  class : string = "",
  key : string = "",
  id : string = "",
  data_effect : string = "",
  click : listener = no_click(),
  input : listener = no_input(),
  enter : listener = no_enter(),
  extra_attrs : list<attr> = Nil,
  extra_events : list<listener> = Nil
) : vnode
  val attrs = prepend_text_attr("placeholder", placeholder, prepend_text_attr("value", value, prepend_text_attr("type", input_type, element_attrs(class, id, data_effect, extra_attrs))))
  el("input", key, attrs, element_events(click, input, enter, extra_events), "", Nil)

pub fun input_text(
  value : string,
  placeholder : string = "",
  class : string = "",
  key : string = "",
  id : string = "",
  data_effect : string = "",
  input : listener = no_input(),
  enter : listener = no_enter(),
  extra_attrs : list<attr> = Nil,
  extra_events : list<listener> = Nil
) : vnode
  val attrs = prepend_text_attr("placeholder", placeholder, prepend_text_attr("value", value, prepend_text_attr("type", "text", element_attrs(class, id, data_effect, extra_attrs))))
  el("input", key, attrs, element_events(no_click(), input, enter, extra_events), "", Nil)

// Use this for CSS classes; prefer small helpers like this over spelling raw `Attr("class", ...)` at call-sites.
pub fun class_attr(value : string) : attr
  Attr("class", value)

// Generic attribute constructor for DOM-facing text attributes like `type`, `value`, or `placeholder`.
pub fun text_attr(name : string, value : string) : attr
  Attr(name, value)

// Low-level click listener constructor.
// In feature code, prefer `on_local_click(...)` from `explore/react/state` so handlers stay typed and can participate in the registry.
pub fun click_listener(payload : string) : listener
  Listener(Click_event, payload)

// Low-level input listener constructor.
// Prefer `on_local_input(...)` in app code unless you intentionally want raw string routing.
pub fun input_listener(payload : string) : listener
  Listener(Input_event, payload)

// Low-level enter-key listener constructor.
// Prefer `on_local_enter(...)` in app code unless you intentionally want raw string routing.
pub fun enter_listener(payload : string) : listener
  Listener(Enter_event, payload)
