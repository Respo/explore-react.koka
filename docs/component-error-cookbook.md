# Component 错误与诊断 cookbook / Component error and diagnosis cookbook

# 中文

这个页面面向已经写出第一个组件、但在 Koka 报错或热更新恢复时卡住的作者。先运行：

```bash
yarn example:first-component
```

它是当前 public API 的持续编译参考。遇到问题时，先读编译器给出的**第一处**错误，再用下面的类别判断它属于 Koka 类型检查、Respo 的 authoring 边界，还是 snapshot recovery 的预期回退。不同 Koka 版本的错误措辞会略有不同；本页使用的是稳定的症状，而不是脆弱的完整错误文本。

| 看到的现象 | 类别 | 先做什么 |
| --- | --- | --- |
| 业务组件导入了 `runtime`、`inspection` 或 `renderer` | 框架边界 | 改回 `import explore/react`，运行 `yarn check:author-surface` |
| 跨模块的 type、constructor 或 value 找不到 | Koka 编译错误 | 检查声明是否为 `pub`，并检查 constructor 大小写 |
| `attrs`、`children` 或属性名不被接受 | Koka 编译错误 / 旧 API | 保留内容位置参数，改用 flat labelled arguments |
| `use_store`、listener 或 effect 让函数签名不匹配 | Koka effect-row 错误 | 复用 feature/app 的 view alias，不要猜测 effect row |
| 列表重排后 draft 跟着错误项目走 | 生命周期诊断 | 为 stateful child 使用 `components(..., key = ...)` |
| HMR/reload 后 local state 回到 initial | 恢复诊断 | 检查 codec 的 schema、version 与 `decode` 兼容性 |

本页不会要求组件作者读取 runtime tree、手拼 scope/path，或直接 import advanced 模块。

## 1. 业务组件导入了 advanced runtime 模块

**症状：** `yarn check:author-surface` 报业务 view 导入了 `explore/react/runtime`、`explore/react/inspection` 或 `explore/react/renderer`。这不是普通的 Koka 类型错误，而是 Respo 为了保持组件 API 简单而设立的 authoring contract。

错误写法：

```koka
import explore/react/runtime
import explore/react/core
```

修复：

```koka
import explore/react
```

`runtime` 负责浏览器/app host 的 callback、effect 和 snapshot transport；`inspection` 与 `renderer` 面向 tests/devtools 和 host。普通组件只描述 `vnode`、typed action/store 与生命周期边界。需要 host 能力时，把它留在类似 [first component 的 executable host](../examples/first_component/main.kk) 的 integration module，而不是把 runtime capability 穿进业务 view。

## 2. 跨模块声明“找不到”或“未导出”

**症状：** 导入另一个模块后，Koka 仍报告 type、value 或 constructor 不可见。最常见原因是被使用的跨模块声明没有 `pub`。

错误写法：

```koka
module my/disclosure

type disclosure_action
  Toggle_disclosure

val disclosure_store = snapshot_store(...)
```

如果另一个模块需要 action type、constructor 或 store，请公开实际要跨模块使用的声明：

```koka
module my/disclosure

pub type disclosure_action
  Toggle_disclosure

pub val disclosure_store = snapshot_store(...)
```

不要为字段或已有声明再加一层单行 accessor wrapper；调用方应直接使用公开的类型、constructor、store 或 struct field。只给真正跨模块的 API 标记 `pub`，内部 helper 继续保持私有。

## 3. Action constructor 名称不匹配

**症状：** `Toggle_disclosure` 类似的 action constructor 被报告为未定义，即使同一个模块里已经声明了 action type。

Koka 的 type constructor 是大写开头。下面声明的是 `Toggle_disclosure`，不是 `toggle_disclosure`：

```koka
pub type disclosure_action
  Toggle_disclosure
```

因此 event 与 codec 中都使用同一个大写 constructor：

```koka
button(
  "Show answer",
  click = on_store_click(
    "toggle-disclosure",
    action = Toggle_disclosure,
    dispatch = dispatch))
```

如果名称在另一个模块定义，也同时检查上一节的 `pub`。可直接对照持续编译的 [示例 action 和 listener](../examples/first_component/component.kk)。

## 4. `attrs` / `children` 或元素 labelled argument 不匹配

**症状：** 调用 `div`、`button` 或 `input_text` 时出现未知 label、参数类型不匹配，或把旧的嵌套 record 形状迁移进来。

Respo 的 element 内容是第一个位置参数，常用属性和事件是压平的 labelled arguments。不要写 `attrs = ...`、`children = ...`：

```koka
div(
  [strong(item.title)],
  key = item.id,
  class = "task-item")

button(
  "Save",
  class = "button",
  click = save_listener)
```

`input_text` 同样把 value 放在第一个位置参数，事件放在 `input = ...`、`enter = ...`：

```koka
input_text(draft, class = "input", input = change_listener)
```

低频 DOM 能力才使用 `extra_attrs` 或 `extra_events`。完整 element 表见 [Component author API](component-authoring.md#1-elements)。

## 5. `use_store` 后函数的 effect row 不再匹配

**症状：** 为组件显式写了一个过窄的返回 effect（例如只写 `<div>`），加入 `use_store`、`on_store_click`、`state_effect` 后 Koka 报 effect 不匹配或缺少 capability。

这不是要把 runtime tree 暴露给业务 view。store、listener 和 scheduled effect 都是 component 生命周期的一部分，函数签名需要使用应用或 feature 已声明的 view alias。可执行示例把复杂行集中在一个命名 alias：

```koka
pub alias disclosure_event_effect =
  <action_observation,local_state_read,local_state_write>

pub alias disclosure_view = component_effect<(),disclosure_event_effect>

pub fun disclosure_panel(key : string = "panel") : disclosure_view vnode
  feature_root("first-component", key) {
    val (open, dispatch) = use_store(disclosure_store, initial = False)
    // ...
  }
```

在 app 内，通常直接复用应用已有的 `app_view` alias；不要在每个 helper 手写一条近似 effect row，也不要为了消除错误而移除 typed store 或 lifecycle boundary。先让私有 helper 的 effect 由其调用位置推导，只有跨模块公开的 component API 才给它一个稳定、命名的 view alias。

## 6. reload/HMR 后状态回到 `initial`

**症状：** 没有编译错误，但刷新或 JavaScript 热替换后某个 local store 以 `initial` 重新开始。

这是 snapshot recovery 的安全回退，不等于 domain model 丢失。`snapshot_store(...)` 与 `replay_store(...)` 只会恢复能够由当前 codec 识别的 state/action。检查以下三项：

1. `schema` 是稳定的语义名称，而不是随实现重命名的字符串；
2. `version` 与 `decode` 支持的版本一致；
3. 旧 payload 改了形状时，decoder 显式迁移，或有意返回 `Nothing` 让该 store 重置。

例如，将 codec 升到 v2 后仍只接受 v1，会让恢复安全回退：

```koka
decode = fn(version, payload) {
  if version == 2 then decode_v2(payload)
  else if version == 1 then migrate_v1(payload)
  else Nothing
}
```

不要让业务 view 读取 snapshot、action log 或 runtime tree 来“修复”恢复。选择 snapshot/replay 以及 version migration 的完整规则见 [Store recovery](store-recovery.md)。

## 7. list 重排或条件隐藏后 local state 对不上

**症状：** 某个输入 draft、展开状态或 resource 在列表重排后附着到另一项；或条件分支消失后你期望保留、实际却被清理。

这是 lifecycle diagnosis，不是 type error。只要 child 有 local state、effect 或 listener，就给它语义稳定的 keyed boundary。列表使用 `components(...)`：

```koka
div(components(
  items,
  group = "tasks",
  key = fn(item) item.id,
  render = task_row))
```

单个 ordinary child 使用 `component(group, key) { ... }`；整个页面 feature 暂时离开 route 仍要保留 snapshot 时使用 `feature_root(group, key) { ... }`。不要手工拼 path，也不要用数组位置当 key。选择与清理语义见 [Component lifecycle](component-lifecycle.md)。

## 何时报告框架问题

先用 `yarn example:first-component` 确认本地 public surface 可编译；再缩小到一个只导入 `explore/react` 的最小组件。若问题仍存在，请报告：Koka 版本、完整的第一条错误、最小源码、期望/实际结果，以及它属于编译、事件、生命周期还是 recovery。不要附带 localStorage snapshot 中的用户数据。

# English

This page is for authors who have written a first component but get stuck on a Koka error or HMR recovery. Start by running:

```bash
yarn example:first-component
```

It is the continuously compiled reference for the current public API. Read the **first** compiler error, then use the categories below to decide whether it is Koka type checking, a Respo authoring boundary, or an expected snapshot-recovery fallback. Koka wording varies slightly by version, so this page names stable symptoms instead of brittle full error text.

| What you see | Category | First action |
| --- | --- | --- |
| A business component imports `runtime`, `inspection`, or `renderer` | Framework boundary | Return to `import explore/react`; run `yarn check:author-surface` |
| A cross-module type, constructor, or value is not found | Koka compile error | Check `pub` and constructor capitalization |
| `attrs`, `children`, or an element property is rejected | Koka compile error / legacy API | Keep positional content and use flat labelled arguments |
| `use_store`, a listener, or an effect breaks a function signature | Koka effect-row error | Reuse a feature/app view alias; do not guess an effect row |
| A draft follows the wrong item after a list reorder | Lifecycle diagnosis | Use `components(..., key = ...)` for stateful children |
| Local state returns to `initial` after HMR/reload | Recovery diagnosis | Check codec schema, version, and `decode` compatibility |

This page never asks component authors to inspect the runtime tree, assemble a scope/path, or directly import advanced modules.

## 1. A business component imports an advanced runtime module

**Symptom:** `yarn check:author-surface` reports that a business view imports `explore/react/runtime`, `explore/react/inspection`, or `explore/react/renderer`. This is not an ordinary Koka type error; it is the Respo authoring contract that keeps the component API small.

Incorrect:

```koka
import explore/react/runtime
import explore/react/core
```

Fix:

```koka
import explore/react
```

`runtime` owns registered callbacks, effects, and snapshot transport for the browser/app host. `inspection` and `renderer` serve tests/devtools and hosts. An ordinary component describes only `vnode`, typed actions/stores, and lifecycle boundaries. Keep host capability in an integration module such as the [first component executable host](../examples/first_component/main.kk), rather than threading runtime capability through a business view.

## 2. A cross-module declaration is “not found” or “not exported”

**Symptom:** After importing another module, Koka still says that a type, value, or constructor is unavailable. The usual cause is that the declaration used across modules is missing `pub`.

Incorrect:

```koka
module my/disclosure

type disclosure_action
  Toggle_disclosure

val disclosure_store = snapshot_store(...)
```

If another module needs the action type, constructor, or store, expose the actual declaration:

```koka
module my/disclosure

pub type disclosure_action
  Toggle_disclosure

pub val disclosure_store = snapshot_store(...)
```

Do not add single-line accessor wrappers around fields or existing declarations. Consumers should use the public type, constructor, store, or struct field directly. Mark only genuine cross-module API as `pub`; keep implementation helpers private.

## 3. An action constructor name does not match

**Symptom:** An action constructor such as `Toggle_disclosure` is reported as undefined even though its action type is declared in the same module.

Koka type constructors start with an uppercase letter. This declaration creates `Toggle_disclosure`, not `toggle_disclosure`:

```koka
pub type disclosure_action
  Toggle_disclosure
```

Use the same uppercase constructor in both event and codec code:

```koka
button(
  "Show answer",
  click = on_store_click(
    "toggle-disclosure",
    action = Toggle_disclosure,
    dispatch = dispatch))
```

When the name comes from another module, also check `pub` from the previous section. Compare the continuously compiled [example action and listener](../examples/first_component/component.kk).

## 4. `attrs` / `children` or an element labelled argument does not match

**Symptom:** Calling `div`, `button`, or `input_text` gives an unknown-label or argument-type error, often after bringing back an old nested record shape.

Respo element content is the first positional argument; common attributes and events are flat labelled arguments. Do not write `attrs = ...` or `children = ...`:

```koka
div(
  [strong(item.title)],
  key = item.id,
  class = "task-item")

button(
  "Save",
  class = "button",
  click = save_listener)
```

`input_text` likewise takes its value first and events as `input = ...` and `enter = ...`:

```koka
input_text(draft, class = "input", input = change_listener)
```

Use `extra_attrs` or `extra_events` only for uncommon DOM capability. The full element table is in [Component author API](component-authoring.md#1-elements).

## 5. An effect row no longer matches after `use_store`

**Symptom:** A component has an explicitly too-narrow return effect (for example only `<div>`), then adding `use_store`, `on_store_click`, or `state_effect` yields an effect mismatch or missing capability.

This does not mean that a business view should expose the runtime tree. Stores, listeners, and scheduled effects are part of component lifecycle, so the signature must use an app or feature view alias already declared for that boundary. The executable example keeps the row in one named alias:

```koka
pub alias disclosure_event_effect =
  <action_observation,local_state_read,local_state_write>

pub alias disclosure_view = component_effect<(),disclosure_event_effect>

pub fun disclosure_panel(key : string = "panel") : disclosure_view vnode
  feature_root("first-component", key) {
    val (open, dispatch) = use_store(disclosure_store, initial = False)
    // ...
  }
```

Inside an app, normally reuse its existing `app_view` alias. Do not hand-write a nearly-correct effect row on every helper, and do not remove a typed store or lifecycle boundary just to silence the error. Let private helpers infer effects from their caller; give only an exported component API a stable named view alias.

## 6. Local state returns to `initial` after reload or HMR

**Symptom:** There is no compile error, but a local store starts from `initial` after refresh or JavaScript hot replacement.

This is a safe snapshot-recovery fallback; it does not mean the domain model was lost. `snapshot_store(...)` and `replay_store(...)` restore only state/actions recognized by the current codec. Check all three:

1. `schema` is a stable semantic name, not a string renamed with an implementation detail;
2. `version` agrees with versions accepted by `decode`;
3. when an old payload changes shape, the decoder explicitly migrates it or deliberately returns `Nothing` to reset that store.

For example, upgrading a codec to v2 while accepting only v1 makes recovery safely fall back:

```koka
decode = fn(version, payload) {
  if version == 2 then decode_v2(payload)
  else if version == 1 then migrate_v1(payload)
  else Nothing
}
```

Do not read snapshots, action logs, or the runtime tree from a business view to “fix” recovery. See [Store recovery](store-recovery.md) for snapshot/replay selection and version-migration rules.

## 7. Local state does not follow a list item or disappears unexpectedly

**Symptom:** An input draft, expanded state, or resource follows another item after a list reorder; or a conditional branch disappears and state is cleaned up when you expected it to remain.

This is a lifecycle diagnosis, not a type error. Whenever a child owns local state, an effect, or a listener, give it a semantically stable keyed boundary. Use `components(...)` for a list:

```koka
div(components(
  items,
  group = "tasks",
  key = fn(item) item.id,
  render = task_row))
```

Use `component(group, key) { ... }` for one ordinary child. Use `feature_root(group, key) { ... }` when an entire page feature temporarily leaves a route but must retain its snapshot. Do not assemble paths by hand or use an array position as a key. See [Component lifecycle](component-lifecycle.md) for ownership and cleanup semantics.

## When to report a framework problem

First use `yarn example:first-component` to confirm that the local public surface compiles, then reduce the problem to a component that imports only `explore/react`. If it still fails, report the Koka version, the complete first error, minimal source, expected/actual behavior, and whether it concerns compilation, events, lifecycle, or recovery. Do not include user data from a localStorage snapshot.
