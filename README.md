# Koka Algebraic Effects in a React-like UI

> This repository is an AI-generated and AI-assisted research prototype. It is
> intended for experimentation, not as a production-ready framework or starter.

This repo explores a React-like component runtime in Koka, with Algebraic
Effects used for browser capabilities, test substitution, component-local
state, and event dispatch.

The current design deliberately separates two kinds of state:

- domain state lives in the application `model` and changes through typed
  feature actions;
- component state lives in a framework-owned runtime tree and changes through
  typed, serializable store actions.

That split keeps business data serializable and inspectable while allowing
component drafts, expanded rows, and other transient UI state to survive a
JavaScript hot replacement or be restored from `localStorage`.

## Current component model

| React idea | This repo in Koka |
| --- | --- |
| view function | a function returning an `app_view vnode` expression |
| keyed component instance | `component(...)` / `components(...)` |
| reusable persistent feature | an exported component owns `feature_root(...)` and may expose labelled `key`; app singletons keep a fixed identity |
| app runtime | one `run_component(...)` call at the integration boundary |
| local reducer | `(state, dispatch) = use_store(spec, initial=...)` |
| local dispatch | `dispatch(action)` or `on_store_*` |
| app reducer/action | `on_action_click(...)` / `on_action_input(...)` / `on_action_enter(...)` |
| `useEffect`-like hook | `state_effect(name=..., deps=..., action=...)` |
| Context-like value | a Koka `val` effect |
| browser/service capability | a Koka `fun` effect |
| test double | an alternate effect handler |

The goal is not API compatibility with React. The useful parts of its mental
model are retained—plain functions, immutable state, stable keyed identity,
and actions—while serialization and capability boundaries are made explicit.

## What component code looks like

Element content is positional. Common attributes and events are flat labelled
arguments, so call sites do not need an `attrs` or `children` wrapper:

```koka
val (Incident_local_state(expanded, draft), dispatch) =
  use_store(incident_local_store, initial = Incident_local_state(False, ""))

article([
  strong(item.title, class = "incident-title"),
  button(
    if expanded then "Collapse" else "Expand",
    class = "button",
    click = on_store_click(
      "toggle-expanded",
      action = Toggle_incident,
      dispatch = dispatch)),
  input_text(
    draft,
    class = "input incident-input",
    input = on_store_input(
      "draft-input",
      action = Change_incident_draft,
      dispatch = dispatch),
    placeholder = "Local reply draft..."),
], key = "incident-" ++ iid.show, class = "incident-card")
```

Public view components follow the same props rule as elements: one primary
domain value stays positional, while callbacks and configuration are labelled.
For example, Search exposes `on_input = ...`, `on_submit = ...`, and
`on_select = ...`; it does not ask callers to manufacture raw DOM payloads or
know which listener registry path the framework assigns.

Component signatures use one application alias, `app_view`, instead of
listing `hook_scope`, state-tree access, scheduled effects, and the listener
registry in every view file. The alias hides runtime plumbing without weakening
the type of the component body.

A function call alone does not create component identity. A stateful reusable
child is evaluated inside `component(...)` or `components(...)`; a persistent
top-level feature establishes `feature_root(...)`. Pure view helpers can remain
ordinary function calls because they do not need their own lifecycle.

Component boundaries use Koka's trailing-lambda syntax—
`feature_root("todo", key) { ... }` and `component("tasks", key) { ... }`—so
lifecycle-bearing code is visually distinct from an ordinary view helper.
Component props and element attributes remain flat labelled arguments.

For repeated children, `components(...)` owns the keyed component boundary:

```koka
fun incident_grid(lab : workflow_lab) : app_view vnode
  div(
    components(
      lab.incidents,
      group = "incidents",
      key = fn(item) incident/id(item).show,
      render = incident_card),
    class = "incident-grid")
```

This is more than a shorter `map`: the `group + key` pair determines the stable
scope used by the child component's state, effects, and named listeners.

An exported feature component owns its stable absolute root and still composes
as a `vnode` expression:

```koka
pub fun todo_panel(
  panel_state : todo_panel_state,
  key : string = "panel"
) : app_view vnode
  feature_root("todo", key) {
    panel(
      [...],
      key = feature_key())
  }
```

Layouts therefore compose components as ordinary values, without receiving or
merging runtime tuples:

```koka
section([
  route_bar(item),
  todo_panel(todo_panel_state_of(item)),
  lab_panel(item),
])
```

The default key preserves the normal singleton path `todo/panel`. Rendering a
second instance gives it an independent component runtime scope:

```koka
todo_panel(todo_panel_state_of(item), key = "compact")
```

That key isolates local stores, effects, listeners, and DOM effect markers.
Domain data is still shared when both instances receive values derived from the
same application model, just as two controlled React components can receive the
same props. `feature_root(...)` installs opaque ambient identity, so descendants
derive a sibling VDOM key with `feature_key()` and a DOM effect marker with
`feature_marker(name)` without receiving `panel_key` props. The default instance
keeps its established browser names; additional instances receive a
group-prefixed name automatically.

Key segments use collision-free URI encoding. Existing non-empty slugs and
numeric IDs keep their established runtime paths. Snapshots created with the
older ambiguous encoding for empty, underscore-leading, or reserved-character
keys fall back to the component's initial value once; current application keys
are unaffected.

Only the app integration boundary installs the runtime:

```koka
run_component(
  item,
  group = "app",
  key = "root",
  render = fn(owner) render_layout(owner, results))
```

The explicit `group + key` remains intentional. Unlike React, an ordinary Koka
function call does not create a fiber identity that the runtime can recover
implicitly across list reordering or hot replacement. Keeping feature roots
absolute also preserves existing snapshot paths when a panel moves in the
layout.

The single runtime collects listeners and scheduled effects in component
evaluation order (shell, active feature tree, then overlay). Components should
not use cross-component effect ordering as a data dependency.

## Typed component stores

Component-local state uses one reducer-backed store rather than several direct
setters. A store combines:

- a state type;
- a serializable action type;
- one pure update function;
- versioned codecs used by the runtime and snapshot boundary.

```koka
pub struct task_editor_state(editing : bool, draft : string)

pub type task_editor_action
  Begin_edit(title : string)
  Change_draft(value : string)
  Finish_edit
  Cancel_edit(title : string)

fun reduce_task_editor(current : task_editor_state, action : task_editor_action)
  match action
    Begin_edit(title) -> Task_editor_state(True, title)
    Change_draft(value) -> Task_editor_state(True, value)
    Finish_edit -> current(editing = False)
    Cancel_edit(title) -> Task_editor_state(False, title)

pub val task_editor_store : store_spec<task_editor_state,task_editor_action> = Store_spec(
  name = "editor",
  state_codec = State_codec(
    schema = "todo/task-editor",
    version = 1,
    decode = decode_task_editor,
    encode = encode_task_editor),
  action_codec = Action_codec(
    schema = "todo/task-editor-action",
    version = 1,
    decode = decode_task_editor_action,
    encode = encode_task_editor_action),
  reduce = reduce_task_editor)
```

Store definitions use labelled fields deliberately. `name` owns runtime
identity, `state_codec` owns snapshot compatibility, `action_codec` owns the
observable wire action, and `reduce` is the pure transition. Avoid positional
`Store_spec(...)`, `State_codec(...)`, and `Action_codec(...)` calls: they are
shorter but make schema/version and encode/decode order too easy to misread.

The component-facing call mirrors React's reducer pair:

```koka
val (Task_editor_state(editing, draft), dispatch) = use_store(
  task_editor_store,
  initial = Task_editor_state(False, item.title))
```

Controls can emit typed store actions without manually reading or writing the
runtime tree:

```koka
input_text(
  draft,
  input = on_store_input(
    "draft-input",
    action = Change_draft,
    dispatch = dispatch))

button(
  "Expand",
  click = on_store_click(
    "toggle-expanded",
    action = Toggle_incident,
    dispatch = dispatch))
```

The codecs are defined once beside the store. They are not passed through every
component call. Explicit scope/path/tree access is reserved for framework and
testing code.

Feature render and panel APIs return only `vnode`. The app boundary owns the
runtime tree through `runtime_frame`, and one `run_component(...)` pass collects
state, scheduled effects, and listeners for the full tree. Parent views also avoid inspecting child stores;
state needed by a parent should be promoted to domain state instead of read
back from a child's local cell.

Simple named state primitives still exist for experiments, but new business
components should prefer a typed store when state can be changed by user
events. This keeps updates action-shaped, observable, and compatible with
future agent-driven action/store tooling.

When a domain action needs a current component value, the component puts that
value into the serializable action. The domain workflow never looks the child
store up by scope:

```koka
val save_edit = fn(owner : model) {
  val next = dispatch(Save_task(draft), owner)
  if draft == "" then () else dispatch_editor(Finish_edit)
  next
}

button("Save", click = on_local_click("save-edit", save_edit))
```

This is the intended use of `on_local_*`: one event coordinates a domain intent
and its own component-store transition. The domain action remains complete
enough for inspection, persistence, or a future agent to submit directly.

## Listener identity and event dispatch

State and listener identity use stable component scopes. Listeners add an event
kind and a semantic name, for example:

```koka
on_action_click("set-done", action = Set_filter("done"), dispatch = dispatch)
on_action_input("change-query", action = Change_search_query, dispatch = dispatch)
on_action_enter("add-task", action = Add_task, dispatch = dispatch)
on_local_input("draft-input", fn(value, owner) ...)
```

When an event only sends a typed domain action, `on_action_click(...)` and
`on_action_input(...)` / `on_action_enter(...)` keep the action constructor,
semantic listener name, and dispatch function visible without repeating a
forwarding closure in every element. `on_local_*` remains the escape hatch for
handlers with custom branching or direct model updates.

At render time `run_event_registry(...)` collects typed Koka callbacks and
returns small listener tokens to the VDOM. `render_node(...)` serializes those
tokens into `data-k-click`, `data-k-input`, or `data-k-enter`. The JavaScript
host only delegates DOM events back to the current Koka registry.

The registry reports duplicate listener ids and semantic drift. This makes
conditional rendering safer without relying on listener call order.

Store listeners are intentionally a narrower convenience layer:

- `on_store_click(...)` emits one typed local action through the store dispatch;
- `on_store_input(...)` converts the input string into one typed local action;
- `on_action_*` dispatches typed domain actions and can still expose reducer
  effects;
- `on_local_*` remains available when an event needs custom component logic.

## Serializable action observation

Domain actions and component-store actions now cross the same observation
boundary. Each dispatch emits an `action_envelope` containing only serializable
data:

```koka
Action_envelope(
  source = "domain",       // or "component"
  target = "todo/tasks/2",
  schema = "todo/task-action",
  version = 2,
  payload = "e")
```

`source` describes ownership, `target` identifies the domain or component
scope, and `schema + version + payload` are owned by the typed action codec. A
single user event may emit more than one envelope. For example, starting a Todo
edit emits the domain intent first and then the component editor-store action.

The observation point is an Algebraic Effect. `capture_actions(...)` gives
tests and other hosts the ordered envelopes without coupling reducers to a
logger. The browser runtime uses `run_runtime_action_observed(...)` to log the
same stream, while `run_runtime_action(...)` deliberately handles and discards
it for callers that do not need observation.

This is an intent log, not a replay engine. Dispatch is observed before the
reducer/workflow runs, so an action remains visible even when confirmation
rejects it. Replaying actions that invoke browser or service effects needs a
separate policy for permissions, deduplication, and recorded responses. Until
that policy exists, the runtime does not automatically persist or replay the
action stream.

## State snapshots, HMR, and reloads

The component runtime tree is encoded as versioned `state_entry` values. Each
entry records its stable path, schema, version, and payload. Restore behavior is
defensive:

- unknown schemas and unsupported versions fall back to the store's initial
  value;
- malformed snapshot data is ignored instead of reaching a component decoder;
- component state is restored only when its keyed scope and store schema still
  match.

`src/main.js` persists the snapshot under
`koka-respo:component-state:v1`. Writes are coalesced with
`requestAnimationFrame`, then flushed synchronously at the important
boundaries:

- before accepting a replacement Koka runtime;
- during Vite HMR disposal;
- on `pagehide`.

The replacement runtime boots from that snapshot, so transient component state
usually survives generated JavaScript replacement. A normal page load restores
the last snapshot from `localStorage`.

This is a best-effort development and recovery mechanism, not a persistence
contract for domain data. Domain data should still have its own application
storage and migration strategy.

## Where Algebraic Effects help

Algebraic Effects are most useful here as capability boundaries, not as a way
to hide the component state tree.

Browser or service operations can be declared directly:

```koka
pub effect fun confirm_action(message : string) : bool
pub effect fun wait_ms(delay : int) : ()
pub effect val current_operator : string
```

Reducers and workflows expose those requirements in their effect rows. The
browser installs production handlers; tests install deterministic handlers for
confirmation, time, network-like responses, audit, and context values. The
business flow itself does not need a mock-specific rewrite.

For local state, effects provide the runtime read/write capability, while the
public component API remains `use_store` plus typed actions. Using effects
alone would not solve identity, serialization, versioning, or HMR restoration;
the typed store and snapshot layers handle those concerns.

## JavaScript boundary

JavaScript remains intentionally thin:

- delegated DOM events;
- DOM mounting and patch application;
- hash reads and writes;
- snapshot persistence and HMR hand-off;
- browser-only capabilities such as confirmation and wall-clock access.

View description, store reducers, registry dispatch, state-tree operations,
diffing, and patch planning remain in Koka.

## Repository map

- `app.kk`: small exported browser bridge.
- `explore/react/core.kk`: VDOM types and flattened element constructors.
- `explore/react/action.kk`: serializable action codecs, envelopes, and the
  observation effect.
- `explore/react/state.kk`: component scopes, typed stores, listeners, effects,
  snapshots, and runtime handlers.
- `explore/react/renderer.kk`: rendering, diffing, and patch planning.
- `demo/*`: application shell, features, actions, stores, and workflows.
- `demo/runtimeframe.kk`: pairs the domain model with the framework runtime tree
  and runs render/action transitions at the app boundary.
- `runtime/*`: DOM and system FFI only.
- `src/main.js`: Vite host, event bridges, HMR, and snapshot persistence.

Recommended reading order:

1. `explore/react/core.kk`
2. `explore/react/action.kk`
3. `explore/react/state.kk`
4. `demo/todo/state.kk`
5. `demo/todo/view.kk`
6. `demo/lab/state.kk`
7. `demo/lab/view.kk`
8. `demo/runtimeframe.kk`
9. `app.kk` and `src/main.js`

## Run locally

The project uses Yarn Berry and expects Koka to be available on `PATH`.

```bash
yarn dev
yarn test:koka
yarn build
```

- `yarn dev` compiles Koka, then starts Vite.
- `yarn test:koka` runs the Koka-side regression suite without a browser.
- `yarn build` compiles Koka and performs the production Vite build.

## Takeaway

The current experiment combines three ideas:

1. React-like plain function components and keyed identity.
2. Reducer-backed, serializable local stores for component interaction.
3. A shared serializable observation stream for domain and component actions.
4. Algebraic Effects for explicit runtime and environment capabilities.

The useful question is not whether this can reproduce React API-for-API. It is
whether typed effects and serializable actions can make component boundaries,
testing, hot replacement, and agent-driven state changes easier to reason
about without making feature code noisy.
