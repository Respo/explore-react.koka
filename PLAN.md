# explore-react 开发计划

## 目标

这里的目标不是追求“React 兼容”这个标签，而是把组件定义方式继续收敛到更接近 React 的心智模型：

- 业务代码描述组件、props、局部交互，而不是手工拼 scope/path
- 应用看起来是一棵组件树，而不是几块手工 orchestration 的 state 岛
- 全局 model 只保留领域数据；组件运行时状态逐步收回框架/runtime
- 顶层 shell 事件与 feature 内部事件尽量走同一套组件 listener 路径模型

## 当前版本和 React 差异较大的地方

### 1. 组件定义仍然泄露 scope/path 细节

当前业务代码虽然已经有 `component_in(...)`、`on_local_*` 这类 helper，但根组件和部分 root-owned 组件仍然要写：

```koka
component(component_local_path("app", "root"), fn() ...)
```

这和 React 里“直接写组件边界，identity 由运行时和 key 决定”的感觉还有明显差距。它不是致命问题，但会持续把框架内部路径模型暴露给业务层。

### 2. 组件本地 runtime state 仍然挂在业务 model 上

现在 `demo/model.kk` 里仍然有 `app_local_tree`。这意味着：

- 领域 model 和运行时状态形状耦合在一起
- feature 在概念上还“拥有自己的 local tree”
- 组件状态尚未真正收敛为 runtime 内部存储

这和 React “组件状态属于运行时，不属于业务数据结构”的边界还差得比较远。

### 3. 顶层 shell 仍然比普通组件更像手工 orchestration

虽然根入口已经统一通过 runtime 跑起来，但 `layout/view/dialog` 这些顶层组合仍然带着明显的“手工 runner 合并”痕迹。React 风格下，shell 应该更像普通组件组合，而不是单独的一套 orchestration 层。

### 4. Hook API 仍然暴露实现细节

当前 `use_state_pair(codec, fallback)` 还要求业务代码显式传 codec。对 React 风格而言，业务代码更接近：

```koka
val (draft, set_draft) = use_state_pair("")
```

codec、slot、序列化策略都更应该是 runtime 内部细节，而不是组件定义的一部分。

### 5. effect 与 Enter 语义仍然偏 runtime 内部实现导向

- `use_effect(...)` 还没有 cleanup 语义
- Enter 仍然复用 click-oriented 的内部存储路径
- 这让 hook/event 模型更像“当前实现的投影”，而不是清晰的组件 API

## 规划原则

后续所有改动都按下面的顺序判断是否值得做：

1. 是否让组件定义方式更接近 React，而不是引入新的 repo 特有概念。
2. 是否减少业务代码里的手工 path/scope/tree 操作。
3. 是否把运行时细节往 `explore/react/*` 收，而不是继续扩散到 `demo/*`。
4. 是否可以用小步迁移验证，不先破坏现有交互、测试和浏览器桥接。

如果某个改动虽然“更抽象”，但让业务代码需要理解更多 repo 自定义概念，那它不算朝 React 靠近。

## 分阶段计划

### Phase 1：先收掉组件定义层的显式路径噪音

目标：

- 让 root-owned 组件声明更像“声明组件边界”，而不是“手工算路径”
- 保持现有 path/key 语义不变，只把内部实现细节藏回 runtime helper

任务：

- 在 `explore/react/state.kk` 提供 root-owned component helper
- 先迁移 `demo/view.kk` 和 `demo/dialogs.kk` 这类已经稳定的 root 组件调用点
- 用现有测试确认 listener/effect/state path 没变

这是当前最安全的第一步，因为它只改变组件定义方式，不改变状态归属、事件分发、host 行为。

### Phase 2：把 app shell 继续收敛成普通组件组合

目标：

- `layout.kk`、`view.kk`、`routebar.kk` 更像组件树组合，而不是手工 merge runner 结果

任务：

- 梳理 shell 层重复的 child runner merge 模式
- 判断这层抽象应该进 `explore/react/state.kk` 还是保留在薄 shell helper
- 只在真实 ownership 边界保留显式 effect/registry merge

### Phase 3：把 local runtime state 从业务 model 中移出去

目标：

- `demo/model.kk` 主要承载领域数据，不继续暴露 runtime tree

任务：

- 先识别一个 app-owned runtime tree 入口
- 从 dialog overlay 开始迁移，再到 todo/lab
- 保持 feature 代码通过组件 helper 读写状态，而不是直接接触 tree 字段

这是和 React 差异最大的结构性问题，但不是最安全的第一刀，所以放在前两步之后。

### Phase 4：继续收紧 hook / effect 语义

目标：

- hook API 看起来更像组件原语，而不是 runtime plumbing

任务：

- 让 `use_state/use_state_pair` 逐步摆脱 codec 暴露
- 重新设计 `use_effect(...)` 的公共契约，避免 host 细节泄露
- 如果 Koka effect handling 可以清晰表达，再补 cleanup 语义
- 让 Enter 拥有独立、直观的 runtime 表达，不再借道 click-oriented 存储

### Phase 5：继续缩小全局 fallback 路径

目标：

- 全局 reducer/controller fallback 成为例外，而不是默认路径

任务：

- route/hash 和真正 app-level 的回退逻辑才保留在全局层
- 继续减少 `demo/todo/events.kk`、`demo/lab/events.kk` 里的 payload 字符串解码
- 优先让组件内部交互走 local registry dispatch

## 当前实施切片

Phase 1 已经完成了安全收口：

- app root、Todo panel、Lab panel、Effects panel、dialog overlay 都已经收成显式组件边界
- shell/root runner 的一层手工 plumbing 已经回收到 runtime helper
- feature 顶层 panel 不再默认借 root scope 工作

Phase 3 的第一刀也已经落地：

- dialog overlay 的 runtime tree 已经从 `model.app_local_tree` 拆出，改为 runtime-owned tree
- 浏览器宿主和 app harness 都会在 render/commit 时单独维护这棵 tree
- dialog overlay 的 effect/listener path 没变，但它不再要求业务 model 持有自己的局部 runtime 分支
- Todo panel 的 render/runtime tree 也已经切到 shared runtime tree，浏览器与测试 harness 会按 Todo listener path 定向桥接这棵 tree
- Todo 的局部编辑 state 不再依赖 render 阶段把 runtime tree 挂回业务 model
- Lab panel 的 render/runtime tree 也已经切到 shared runtime tree，workflow/search/bridge shell 不再靠 render 时读取 `model.app_local_tree`
- Lab 本地 listener 路径现在和 Todo 一样，统一通过宿主/测试桥接把 runtime tree 临时注入回调，再在回调后抽离
- 这层过渡桥接已经收敛到 `demo/runtimebridge.kk`，browser、app harness、component harness 不再各自复制 `attach/detach + path 判断`
- owner 上暂挂 runtime tree 的读写也已经收敛到 `demo/runtimeowner.kk`，Todo/Lab helper 不再直接读写 `model.app_local_tree`
- browser 宿主和 app harness 这一层也已经切到 `demo/runtimeframe.kk`，不再手工传 `(model, runtime_tree)` tuple

当前下一步应该是：

- 继续把 component harness 也评估是否切到 `runtime_frame`，把 app-level runtime owner 语义彻底统一
- 再考虑是否把 `model.app_local_tree` 从业务 model 形状中彻底移除，只给 runtime frame 持有

判断标准保持不变：如果业务代码更少接触 runtime tree/path，同时组件树边界更清晰，那就是朝 React 组件定义方式更近，而不是更远。

## 非目标

- 不追求 SSR 或 hydration
- 不追求 1:1 复刻 React internals
- 不为了“hook 数量对齐 React”而引入额外复杂度
- 不在组件/runtime ownership 还没理顺前，先做 DOM 微优化# explore-react Plan

## Goal

The target is not "React compatibility" as branding. The target is a clearer React-style component model:

- business code should describe components and local interactions, not manual scope plumbing
- app structure should look like one component tree, not several hand-wired state islands
- global model should keep domain data; component runtime state should move toward framework-owned storage
- app-level events should use the same component listener path as feature-level events whenever practical

## Directory View

### `explore/react/*`

Framework core. This directory should keep moving toward the real component runtime boundary.

- `core.kk`: vnode constructors and small DOM-facing helpers
- `state.kk`: hook scopes, local state cells, effect scheduling, listener registry, component runners
- `renderer.kk`: render, diff, and patch planning

Current status:

- local hook APIs and named local listeners are in place
- `component_in(...)`, `on_local_*`, and named state helpers already hide most slot details from business code
- listener registries can detect duplicate ids and semantic drift

Main problems still open here:

- root app rendering is still thinner than child component rendering
- `use_effect(...)` still leaks host-specific `root_id` and has no cleanup contract
- Enter is still modeled through click-oriented storage/dispatch internals
- local state still lives in feature-owned trees stored on the app model

### `demo/*`

Feature and shell layer. This directory should become a thin composition layer around the framework runtime.

- `model.kk`: shared domain data and cross-feature effect declarations only
- `layout.kk`, `view.kk`, `routebar.kk`: app shell and top-level composition
- `todo/*`: todo feature
- `lab/*`: workflow/search/bridge feature
- `dialogs.kk`, `effectspanel.kk`: overlay/effect demos

Current status:

- todo item actions are already mostly local-listener driven
- dialog open/close/submit flows are already local-listener driven
- lab incident card interactions use component-local listeners and local state helpers

Main problems still open here:

- app shell still manually orchestrates several stateful slices and then merges handlers/effects
- route bar still needs to follow the same component-local event model as feature views
- `demo/model.kk` still stores feature local trees, so feature runtime state still leaks into app data shape

### `boilerplate/*` and `runtime/*`

Host boundary only.

- browser boot
- delegated DOM events
- hash sync
- DOM patch application
- confirm/time/bridge host wiring

Rule:

- keep this thin
- do not move feature behavior here
- only host-specific mechanics belong here

### `library/*`

Shared domain helpers and effect-oriented utilities.

- route, dialog, maybe, search, bridge

Rule:

- keep reusable data contracts and helper logic here
- do not let this directory become a second controller layer

### `demo/tests/*`

Regression surface for the React-style component runtime.

Required coverage direction:

- vnode payloads should match registered local listeners
- component-local state should survive rerender and reset only on real identity changes
- shell-level interactions should use the same registry path model as feature-level interactions
- runtime warnings and event dispatch edge cases should stay deterministic

## Task Breakdown

### Phase 1: Make the app shell behave like a component tree

Target:

- app root gets an explicit component/runtime entry
- route bar and other shell interactions stop using raw global click payloads when they can use local listeners
- tests assert shell listener paths the same way they already assert todo/dialog paths

Tasks:

- add a root app component runner in `demo/view.kk`
- move `demo/routebar.kk` to local component listeners
- route app-level harness/tests through the same runtime entry

### Phase 2: Reduce manual orchestration in the shell

Target:

- `layout.kk` should stop looking like a hand-merged collection of islands

Tasks:

- factor repeated child runner merge patterns behind framework helpers
- decide whether stateful child composition belongs in `explore/react/state.kk` or a thin app-shell helper layer
- keep effect/registry merging explicit only where ownership boundaries are real

### Phase 3: Move local runtime state out of domain model shape

Target:

- `demo/model.kk` should carry domain state, not per-feature runtime storage details

Tasks:

- identify one root-owned local state tree shape in framework/runtime code
- migrate `todo_local_tree`, `lab.local_tree`, and `dialog_local_tree` toward framework-owned storage
- keep feature code reading local state through component helpers, not tree fields

### Phase 4: Tighten hook and effect semantics

Target:

- make hook APIs look more like component runtime primitives and less like host plumbing

Tasks:

- redesign `use_effect(...)` so host-specific root lookup is not the public component contract
- add cleanup support if Koka effect handling can express it cleanly enough
- normalize Enter handling so it is not stored and dispatched through click-oriented paths

### Phase 5: Trim global fallback routing

Target:

- global reducer/controller fallback should be the exception, not the normal feature path

Tasks:

- keep route/hash and true app-level fallbacks global only where necessary
- continue shrinking raw payload decoding in `demo/todo/events.kk` and `demo/lab/events.kk`
- prefer component-local registry dispatch over string decoding when the interaction originates inside a rendered component

## Current Working Set

The next implementation slice is the first Phase 3 migration.

- keep the shared app-owned runtime tree small at first
- migrate dialog overlay local runtime state before moving todo/lab
- validate that the shared tree is keyed by component paths rather than feature-specific storage slots

## Non-Goals

- SSR or hydration
- a 1:1 port of React internals
- hook parity for its own sake
- premature DOM optimization before the component/runtime ownership model is cleaner
