# Component author API

# 中文

普通业务组件只导入三个模块：

```koka
import explore/react/core
import explore/react/action
import explore/react/state
```

这三个模块分别承载 elements/VDOM、serializable action protocol，以及 component lifecycle/store/effect authoring。不要在业务 view 中导入 `explore/react/runtime`、`explore/react/inspection` 或 `explore/react/renderer`。

## 1. Elements

| 任务 | 推荐 API |
| --- | --- |
| container | `div/section/article/aside/header/nav/ul/li(children, class = ..., key = ...)` |
| text element | `span/strong/p/h1/h2/h3(text, class = ..., key = ...)` |
| interaction | `button(text, click = ...)`, `input_text(value, input = ..., enter = ...)` |
| uncommon DOM capability | `extra_attrs` / `extra_events` |

主要内容始终是第一个位置参数；常用属性和事件保持 flat labelled arguments。不要恢复 `attrs = ..., children = ...` 的嵌套形态。

## 2. Keyed components

| 任务 | 推荐 API |
| --- | --- |
| ordinary keyed child | `component(group, key) { ... }` |
| keyed collection | `components(items, group = ..., key = ..., render = ...)` |
| persistent page feature | `feature_root(group, key) { ... }` |
| feature-owned VDOM/effect identity | `feature_key()` / `feature_marker(name)` |

普通 view helper 不建立 identity。只有 local state、effect 或 listener 需要独立 lifecycle 时才建立 keyed boundary。

## 3. Typed stores and actions

| 任务 | 推荐 API |
| --- | --- |
| action protocol | `Action_codec(schema = ..., version = ..., decode = ..., encode = ...)` |
| full-state recovery | `snapshot_store(name = ..., state_codec = ..., action_codec = ..., reduce = ...)` |
| bounded session replay | `replay_store(name = ..., action_codec = ..., replay = ..., reduce = ...)` |
| component reducer pair | `(state, dispatch) = use_store(spec, initial = ...)` |
| component action event | `on_store_click/input(name, action = ..., dispatch = ...)` |
| domain action event | `on_action_click/input/enter(name, action = ..., dispatch = ...)` |
| one domain + one local action | `action_store_transition(action, dispatch = ..., store_action = ..., store = ..., store_when = ...)` |
| custom handler | `on_local_click/input/enter(name, handler)` |

domain reducer 不读取 child store。组件需要提交 draft 时，把值放进 serializable domain action。复杂分支才使用 `on_local_*`。

## 4. Effects

| 任务 | 推荐 API |
| --- | --- |
| render 后按 deps 调度 | `state_effect(name = ..., deps = ..., action = ...)` |
| browser/service capability | Koka `fun` effect + app/test handler |
| ambient read-only value | Koka `val` effect |

effect name 在同一 component boundary 内保持稳定。业务 workflow 显式声明 confirm、timer、request 等 capability；不要隐藏到 snapshot/replay 或 arbitrary callback 中。

## Advanced modules

| 模块 | 使用者 |
| --- | --- |
| `explore/react/runtime` | browser/app host：运行 registered callbacks、scheduled effects、snapshot transport |
| `explore/react/inspection` | tests/devtools：查询 VDOM、event registry 与 runtime entry count |
| `explore/react/renderer` | host/tests：render、diff、patch |

这些模块不是 component authoring surface。更深入的恢复和生命周期规则见 [store recovery](store-recovery.md) 与 [component lifecycle](component-lifecycle.md)。

# English

Ordinary business components import only three modules:

```koka
import explore/react/core
import explore/react/action
import explore/react/state
```

They provide elements/VDOM, the serializable action protocol, and component lifecycle/store/effect authoring. Business views do not import `explore/react/runtime`, `explore/react/inspection`, or `explore/react/renderer`.

## 1. Elements

| Task | Preferred API |
| --- | --- |
| Container | `div/section/article/aside/header/nav/ul/li(children, class = ..., key = ...)` |
| Text element | `span/strong/p/h1/h2/h3(text, class = ..., key = ...)` |
| Interaction | `button(text, click = ...)`, `input_text(value, input = ..., enter = ...)` |
| Uncommon DOM capability | `extra_attrs` / `extra_events` |

Primary content is always the first positional argument. Common attributes and events remain flat labelled arguments; do not restore a nested `attrs = ..., children = ...` shape.

## 2. Keyed components

| Task | Preferred API |
| --- | --- |
| Ordinary keyed child | `component(group, key) { ... }` |
| Keyed collection | `components(items, group = ..., key = ..., render = ...)` |
| Persistent page feature | `feature_root(group, key) { ... }` |
| Feature-owned VDOM/effect identity | `feature_key()` / `feature_marker(name)` |

An ordinary view helper does not establish identity. Add a keyed boundary only when local state, effects, or listeners need an independent lifecycle.

## 3. Typed stores and actions

| Task | Preferred API |
| --- | --- |
| Action protocol | `Action_codec(schema = ..., version = ..., decode = ..., encode = ...)` |
| Full-state recovery | `snapshot_store(name = ..., state_codec = ..., action_codec = ..., reduce = ...)` |
| Bounded session replay | `replay_store(name = ..., action_codec = ..., replay = ..., reduce = ...)` |
| Component reducer pair | `(state, dispatch) = use_store(spec, initial = ...)` |
| Component action event | `on_store_click/input(name, action = ..., dispatch = ...)` |
| Domain action event | `on_action_click/input/enter(name, action = ..., dispatch = ...)` |
| One domain + one local action | `action_store_transition(action, dispatch = ..., store_action = ..., store = ..., store_when = ...)` |
| Custom handler | `on_local_click/input/enter(name, handler)` |

A domain reducer never reads a child store. Put a draft or other current component value into the serializable domain action. Use `on_local_*` only for genuinely custom branching.

## 4. Effects

| Task | Preferred API |
| --- | --- |
| Schedule after render by dependencies | `state_effect(name = ..., deps = ..., action = ...)` |
| Browser/service capability | A Koka `fun` effect with app/test handlers |
| Ambient read-only value | A Koka `val` effect |

Keep effect names stable within one component boundary. Business workflows declare confirm, timer, request, and similar capabilities explicitly; do not hide them in snapshot/replay or arbitrary callbacks.

## Advanced modules

| Module | Audience |
| --- | --- |
| `explore/react/runtime` | Browser/app hosts: registered callbacks, scheduled effects, and snapshot transport |
| `explore/react/inspection` | Tests/devtools: VDOM, event-registry, and runtime-entry queries |
| `explore/react/renderer` | Hosts/tests: render, diff, and patch |

These modules are not part of the component-authoring surface. See [store recovery](store-recovery.md) and [component lifecycle](component-lifecycle.md) for the deeper contracts.
