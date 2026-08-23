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
| function component | a plain function returning `vnode` |
| keyed child component | `components(items, group=..., key=..., render=...)` |
| component boundary | `component_root(...)` / `component_in(...)` |
| local reducer | `use_store(spec, initial=...)` |
| local dispatch | `binding.send(action)` or `on_store_*` |
| app reducer/action | typed feature actions dispatched through the app runtime |
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
article([
  strong(item.title, class = "incident-title"),
  button(
    if expanded then "Collapse" else "Expand",
    class = "button",
    click = on_store_click("toggle-expanded", local, Toggle_incident)),
  input_text(
    draft,
    class = "input incident-input",
    input = on_store_input("draft-input", local, Change_incident_draft),
    placeholder = "Local reply draft..."),
], key = "incident-" ++ iid.show, class = "incident-card")
```

For repeated children, `components(...)` owns the keyed component boundary:

```koka
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

fun update_task_editor(current : task_editor_state, action : task_editor_action)
  match action
    Begin_edit(title) -> Task_editor_state(True, title)
    Change_draft(value) -> Task_editor_state(True, value)
    Finish_edit -> current(editing = False)
    Cancel_edit(title) -> Task_editor_state(False, title)
```

The component-facing call stays small:

```koka
val editor = use_store(
  task_editor_store,
  initial = Task_editor_state(False, item.title))
val Task_editor_state(editing, draft) = editor.current
```

Controls can emit typed store actions without manually reading or writing the
runtime tree:

```koka
input_text(
  draft,
  input = on_store_input("draft-input", editor, Change_draft))

button(
  "Expand",
  click = on_store_click("toggle-expanded", local, Toggle_incident))
```

The codecs are defined once beside the store. They are not passed through every
component call. Explicit scope/path/tree access is reserved for framework code
and the small amount of feature coordination that must address a component
outside its render function.

Feature render and panel APIs do not receive or return the runtime tree. The app
boundary owns it through `runtime_frame`, and `run_runtime_render(...)` threads
it through component runners. Parent views also avoid inspecting child stores;
state needed by a parent should be promoted to domain state instead of read
back from a child's local cell.

Simple named state primitives still exist for experiments, but new business
components should prefer a typed store when state can be changed by user
events. This keeps updates action-shaped, observable, and compatible with
future agent-driven action/store tooling.

## Listener identity and event dispatch

State and listener identity use stable component scopes. Listeners add an event
kind and a semantic name, for example:

```koka
on_local_click("save-edit", fn(owner) ...)
on_local_input("draft-input", fn(value, owner) ...)
on_local_enter("send-reply", fn(owner) ...)
```

At render time `run_event_registry(...)` collects typed Koka callbacks and
returns small listener tokens to the VDOM. `render_node(...)` serializes those
tokens into `data-k-click`, `data-k-input`, or `data-k-enter`. The JavaScript
host only delegates DOM events back to the current Koka registry.

The registry reports duplicate listener ids and semantic drift. This makes
conditional rendering safer without relying on listener call order.

Store listeners are intentionally a narrower convenience layer:

- `on_store_click(...)` emits one typed local action;
- `on_store_input(...)` converts the input string into one typed local action;
- `on_local_*` remains available when the event also changes the owner model or
  invokes other effects.

## Serializable action observation

Domain actions and component-store actions now cross the same observation
boundary. Each dispatch emits an `action_envelope` containing only serializable
data:

```koka
Action_envelope(
  source = "domain",       // or "component"
  target = "todo/tasks/2",
  schema = "todo/task-action",
  version = 1,
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
