module examples/first_component/component

import explore/react

pub type disclosure_action
  Toggle_disclosure

pub val disclosure_action_codec : action_codec<disclosure_action> = Action_codec(
  schema = "example/disclosure-action",
  version = 1,
  decode = fn(version, payload) {
    if version == 1 && payload == "toggle" then Just(Toggle_disclosure) else Nothing
  },
  encode = fn(_action) "toggle")

pub val disclosure_store : store_spec<bool,disclosure_action> = snapshot_store(
  name = "open",
  state_codec = bool/state_codec,
  action_codec = disclosure_action_codec,
  reduce = fn(open, _action) not(open))

pub alias disclosure_event_effect = <action_observation,local_state_read,local_state_write>
pub alias disclosure_view = component_effect<(),disclosure_event_effect>

pub fun disclosure_panel(key : string = "panel") : disclosure_view vnode
  feature_root("first-component", key) {
    val (open, dispatch) = use_store(disclosure_store, initial = False)
    section([
      h2("A first Respo component"),
      p(if open then "State: open" else "State: closed"),
      button(
        if open then "Hide answer" else "Show answer",
        click = on_store_click(
          "toggle-disclosure",
          action = Toggle_disclosure,
          dispatch = dispatch)),
      if open then p("This answer is rendered from typed component state.") else span(""),
    ], key = feature_key(), class = "first-component")
  }
