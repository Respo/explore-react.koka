# Koka Algebraic Effects in a React-like UI

> This repository is an AI-generated and AI-assisted experimental project.
>
> Treat it as a research prototype, not as a recommended framework or a production-ready starter.
>
> The suggested way to use it is to fork it and continue the exploration in your own direction.
> It is not recommended to adopt it directly as-is.

This repo explores one specific question:

Can Algebraic Effects be used as a first-class architectural tool in a React-like frontend system?

The answer here is not “React rewritten in Koka”. The result is closer to a small explore-react runtime with a React-like mental model plus some deliberate constraints:

- components are still plain functions returning virtual DOM
- local UI state still uses hook-like APIs
- global business updates still prefer typed action dispatch
- local closure listeners are allowed, but must use stable semantic names
- browser and tests install different handlers over the same UI logic

The main value of the repo is this exploration of the boundary between frontend frameworks and Algebraic Effects.

## What this repo is actually exploring

Most frontend frameworks are already good at rendering trees from state. The harder parts are usually at the edges:

- async workflows get spread across hooks, services, and callback glue
- browser APIs leak into components
- Context grows implicit and hard to audit
- tests need framework-specific mocking layers
- event boundaries become convention-heavy and easy to blur

This repo explores a different split:

1. Keep view description, state transitions, and diff/patch planning in Koka.
2. Keep JavaScript limited to DOM and browser boundaries.
3. Use Algebraic Effects to model the capabilities the UI logic needs.
4. Keep components close to React’s mental model, but make capability boundaries explicit in types.

That makes the interesting question not “can Koka render a todo app?”, but “what changes when frontend capabilities become typed effects instead of conventions?”

## How the component model maps to React

The overall shape is intentionally familiar.

| React idea            | This repo in Koka                                                       |
| --------------------- | ----------------------------------------------------------------------- |
| function component    | `demo/*panel.kk` and `demo/*/view.kk` functions returning `vnode`       |
| reducer update        | functions returning a fresh `model`                                     |
| local hook state      | `component(scope, ...)` + `use_state(...)` / `use_state_pair(...)`      |
| `useEffect`-like hook | `use_effect(...)` over a stable component scope                         |
| event props           | global action listeners or named local listeners                        |
| Context               | `val` effects such as `current_operator`                                |
| async service layer   | `fun` effects such as `wait_ms`, `fetch_lab_snapshot`, `post_lab_reply` |
| test doubles          | alternate effect handlers in test modules                               |

The important difference is that React usually leaves these boundaries as framework convention, while Koka makes them part of the function type and handler installation model.

## What component code looks like now

The component style is meant to stay close to the “plain function UI” feel that makes React ergonomic, but with slightly stronger framework helpers so business components stay smaller.

For example, the todo panel still renders as a function of the current model:

```koka
alias todo_view_effect = <push_hook_scope,pop_hook_scope,use_state_pair,use_effect,register_listener<model,browser_event_effect>,div>

pub fun render_todo_panel(item : model) : todo_view_effect vnode
  component(todo_effect_scope(), fn() {
    val panel_scope = todo_effect_scope()
    val visible = tasks_for(model_filter_name(item), model_tasks(item))
    val total = count_all(model_tasks(item))
    use_effect([model_notice(item), model_draft(item), total.show], fn(root_id) {
      if is_recent_add(item) then browser_focus(root_id, "draft") else ()
    })
    panel("Todo", model_notice(item), "todo", "todo-panel", [
      node_class("div", "composer", "composer-row", [
        text_input("draft", "input", model_draft(item), "Add a task or effect experiment...", Nil, [
          on_named_input(panel_scope, "draft-input", fn(value, owner) set_draft(owner, value)),
          dispatch_todo_enter(Add_task),
        ]),
        button_class("add-task", "button button-primary", [dispatch_todo_click(Add_task)], "Add"),
      ]),
      task_list("visible-tasks", visible),
    ])
  })
```

What is notable here is not the syntax by itself. It is the division of responsibility:

- the view stays a plain function
- local UI state still exists through hook-like APIs
- event entry points are explicit
- framework helpers like `node_class`, `text_class`, `button_class`, and `text_input` reduce component boilerplate
- capabilities remain typed instead of hidden in ambient services or browser objects

That is the point where Algebraic Effects start to matter for frontend architecture.

## The key constraint: hooks and listeners do not use the same stability rule

One important conclusion from this repo is that not every component mechanism should copy React hooks exactly.

### Hooks use `scope + index`

For local state and local effect hooks, the repo keeps a React-like rule:

- `component(scope, ...)` establishes a stable component scope
- `use_state(...)`, `use_state_pair(...)`, and `use_effect(...)` then use call order inside that scope

This keeps hook usage compact and familiar.

### Listeners use `scope + event kind + semantic name`

Event listeners are different.

Conditional rendering often changes listener appearance order, so using hook-style index addressing for listeners is fragile. The current design instead treats listener identity as semantic:

- hooks are stable because order is stable
- listeners are stable because names are stable

That is why local listeners are written as:

```koka
on_named_click(item_scope, "cancel-edit", fn(owner) ...)
on_named_input(item_scope, "draft-input", fn(value, owner) ...)
on_named_enter(item_scope, "submit-reply", fn(owner) ...)
```

And the public effect row only tracks one generic listener capability:

- `register_listener<model,browser_event_effect>`

instead of separately exposing `on_click`, `on_input`, and `on_enter` in every component alias.

This is a deliberate difference from React’s default event story. It adds some framework machinery, but it keeps business components from relying on unstable listener ordering.

## How listener registration works

At render time, local listeners are not attached directly as JS closures on DOM nodes.

Instead, the framework does three things:

1. `on_named_*` turns a semantic name into a stable listener slot path.
2. `run_event_registry(...)` handles `register_listener(...)`, collects the callback into an `event_registry`, and returns a lightweight `listener(kind, payload)` token into the VDOM.
3. `render_node(...)` serializes that token into `data-k-click`, `data-k-input`, or `data-k-enter` attributes.

Then the browser bridge in `runtime/inline/dom.js` uses delegated root listeners to:

- read the `data-k-*` payload
- call the exported Koka dispatch bridge
- resolve the payload back to the current handler registry or fallback reducer dispatch

This means the DOM layer stays thin and string-based, while the Koka side keeps typed closures and effect-aware state transitions.

## Listener guardrails against duplicate ids and semantic drift

Because listener identity is semantic, the framework now also carries framework-side protections in `explore/react/state.kk`:

- local registry collection detects duplicate listener ids inside a render pass
- merged registries also detect collisions across composed panels
- each registered local listener carries a `semantic_name`
- warnings are produced for:
  - duplicate registration of the same listener id
  - semantic drift, where the same listener id is reused for a different meaning
- `app.kk` logs these warnings during boot and commit

This is another intentional difference from React. The repo accepts a bit more framework complexity so business components can stay simpler and safer under conditional rendering.

## Where Algebraic Effects change the design

### 1. Side effects become explicit UI capabilities

Instead of a reducer or event path closing over `window.confirm()` or some service singleton, the code declares what it needs:

```koka
pub effect fun confirm_action(message : string) : bool
pub effect fun audit(message : string) : ()
```

Then a reducer can say:

```koka
pub fun handle_remove(item : model, payload : string) : <confirm_action,audit,div> model
```

That means the UI logic depends on confirmation and audit, but does not decide how those capabilities are implemented.

In the browser boundary, `app.kk` installs one behavior. In tests, the same code runs under different handlers.

This is one of the clearest places where Algebraic Effects are a better fit than common React patterns: the dependency is visible in the type, not hidden in a closure or convention.

### 2. Async workflows stay in one reducer-shaped flow

The workflow demo uses effects like:

```koka
pub effect fun wait_ms(delay : int) : ()
pub effect fun fetch_lab_snapshot() : lab_snapshot
pub effect fun post_lab_reply(incident_id : int, message : string) : string
pub effect fun now_label() : string
pub effect val current_operator : string
```

This lets a workflow action express a frontend flow directly:

1. validate local draft state
2. emit audit
3. wait for staged time
4. fetch or post data
5. stamp with time and operator
6. return the next immutable model

In a React codebase, this kind of logic often gets split across hook state, service helpers, async callbacks, and mock-specific test code.

Here the experiment is: keep it in one typed reducer-like path, and swap implementations by installing handlers.

### 3. Ambient values become explicit without provider ceremony

The repo also uses `val` effects for contextual values such as operator identity.

```koka
pub effect val current_operator : string
```

This plays a role similar to React Context, but with different tradeoffs:

- the dependency is explicit in the function type
- the binding is lexical
- tests can override it with a tiny local handler
- there is less provider-tree ceremony

This is another useful direction for frontend exploration: context-like behavior with smaller framework surface area.

### 4. Tests use the same capability surface as production

The production code and the tests use the same effect surface.

For example, timer-heavy logic can be tested by handling `wait_ms` immediately and collecting delays, while workflow tests can install fake timestamps, fake operator identity, fake server responses, and audit collectors.

That means the business path is not rewritten for tests. Only the handlers change.

This is one place where Algebraic Effects fit frontend work unusually well: UI logic is full of environment-dependent behavior, and handlers give that environment a clean, typed boundary.

## Compared to React: what is preserved, what is changed

### Preserved

- components are still plain functions
- local state still uses hook-like ergonomics
- reducers and typed actions are still a good fit for global state changes
- delegated events still make sense at the host boundary

### Changed

- function signatures make capability needs explicit
- listener identity is semantic rather than positional
- local closure listeners and global action dispatch are treated as distinct architectural tools
- tests and production differ by handler installation, not by mock-heavy rewrites
- the framework is willing to become slightly more opinionated so business components can stay smaller

So the point is not to recreate React API surface area exactly. The point is to keep the useful component mental model while rethinking capability boundaries.

## What JavaScript still does

JavaScript is still used, but only at the host boundary:

- delegated DOM events
- DOM patching and mounting
- browser hash reads and writes
- browser confirm
- logging of framework/runtime warnings
- wall-clock labels and similar host data

Everything above that line is what this repo is trying to keep in Koka.

## If you want to explore this repo

Recommended mindset:

1. Fork it.
2. Treat it as a design sketch, not a final framework.
3. Change the handler surface first, not the renderer details.
4. Pay close attention to where component ergonomics improve or regress compared with the equivalent React design.
5. Evaluate whether the added framework constraints actually reduce feature-level complexity.

Useful reading order:

1. `app.kk`
2. `explore/react/core.kk`
3. `explore/react/state.kk`
4. `demo/todo/view.kk`
5. `demo/lab/view.kk`
6. `demo/lab/workflow.kk`
7. `demo/tests/support.kk`

Run locally with:

```bash
yarn dev
yarn build
yarn test:koka
```

## Takeaway

This repo is not arguing that frontend teams should stop using React and move to Koka.

It is a narrower claim:

Algebraic Effects appear to be a promising tool for frontend framework design, especially for modeling capabilities that React apps usually express through informal conventions: async workflows, browser integration, contextual values, test doubles, and event boundaries.

If that is the question you care about, this repo is worth forking and pushing further.
