# explore-react 开发计划

## 方向

当前目标不是复制 React API，而是收敛出适合 Koka 的组件模型：

- 组件仍然是返回 `vnode` 的普通函数；
- element 使用位置内容 + 扁平 labelled arguments；
- keyed component identity 由框架 helper 管理；
- 业务 model 只保存领域数据；
- component runtime state 使用 typed store 和 serializable actions；
- Algebraic Effects 表达 runtime 与浏览器能力，不把 path/tree 细节暴露给组件；
- runtime snapshot 能跨 Vite HMR，并可从 `localStorage` best-effort 恢复。

这一方向也为 agents/actions/store 模式准备统一入口：agent 和用户事件都应尽量发送可验证、可序列化的 action，而不是直接改组件内部值。

## 已完成的设计收口

### Element API

- container content 保持第一个位置参数，文本 element 的文本也保持位置参数；
- `class`、`key`、`id`、`click`、`input`、`enter` 等压平为 labelled arguments；
- 撤回 `attrs + children` 嵌套 record 方案；
- `extra_attrs` / `extra_events` 只作为低频 escape hatch。

### Component identity

- app 集成层只运行一次 `run_component(owner, group = ..., key = ..., render = ...)`；
- Todo、Lab、Effects 等可复用 feature component 自己持有 `feature_root(...)`，以 labelled `key` 隔离 local store、effect、listener 和 DOM marker，对外只返回 `vnode`；domain data 是否共享仍由传入 props 决定；全局 Dialog overlay 明确为 app-owned singleton，不暴露半完整的多实例 key；
- 单个 child 边界由 `component(...)` 表达；
- 列表统一使用 `components(items, group = ..., key = ..., render = ...)`；
- 单个 component/feature boundary 使用 trailing-lambda block（`component(group, key) { ... }`），让带 lifecycle 的调用在语法上与普通 view helper 明显区分；
- `feature_root(...)` 安装 opaque ambient identity；内部 helper 用 `feature_key()` / `feature_marker(name)` 派生 VDOM key 与 DOM marker，不再转发 `panel_key`；
- `component_effect<s,e>` 在应用侧绑定为 `app_view`，view 不再展开 framework effect row；
- 业务组件不再手工拼装 listener/effect/store path；
- state、effect 和 named listener 共享稳定的 keyed component scope。

### Component lifecycle

- `feature_root(...)` 是 persistent boundary：整个 feature 未 render 时保留 snapshot，支持 route 返回、HMR 和 reload；
- `component(...)` / `components(...)` 是 ordinary child boundary：当前 feature 仍 render、但 child 不再访问时执行 unmount sweep；
- runtime 使用可持久化的 `respo/component-scope` marker 记录 child 归属，不根据 path 形状猜测业务结构；
- sweep 删除普通 child 的 store、effect metadata 与 lifecycle marker；listener registry 每轮重建，不需要持久化清理；
- Todo 删除单项与 Clear done 都由 render lifecycle 自动释放 editor state，不再由 domain reducer 清理 path；
- app-owned persistent singleton 仍可在 integration boundary 使用 `reset_feature(...)` 显式重置；
- 完整契约见 [`docs/component-lifecycle.md`](docs/component-lifecycle.md)。

### Typed component store

- `store_spec<s,a>` 将 action codec、纯 reducer 和显式 recovery policy 组合在一起；
- `snapshot_store(...)` 保存完整 typed state，适合累积、toggle 或不能安全压缩的 reducer；
- `replay_store(...)` 保存当前 session 内压缩后的 typed component actions，不要求 state codec；
- replay policy 只提供 `Replay_start` / `Replay_replace(slot)` / `Replay_reset`，框架不通过截断任意 action 历史换取有界日志；
- Todo editor 使用 replay recovery，Lab incident 继续使用 snapshot recovery，组件调用保持同一个 `use_store(...)` reducer pair；
- store 与 codec 定义使用完整 labelled fields，使 runtime identity、recovery、action schema 与 reducer 职责在声明处清晰分组；
- 组件调用收敛为 `(state, dispatch) = use_store(spec, initial = ...)`，对齐 React `useReducer`；
- `on_store_click(...)` / `on_store_input(...)` 使用 labelled `action + dispatch` 直接发 typed action；
- binding record 与 `.current` / `.send` 不再暴露给业务 view；
- domain reducer/workflow 不反查或写入 child store；需要当前 draft 等值时，由组件放进 serializable domain action；
- Todo editor 与 Lab incident local state 已完成迁移；
- codec、slot 和 tree 编解码不再出现在普通 view 调用点。

### Typed domain-action listeners

- `on_action_click(...)` / `on_action_input(...)` / `on_action_enter(...)` 直接连接 typed action 与 feature dispatch；
- `action_store_transition(...)` 表达“一个 domain action，然后按条件发送一个 component-store action”，并由 click/Enter 复用同一个 handler；
- action、dispatch 使用 labelled arguments，在 element 调用点保持可读；
- Todo、Lab、Route 已移除仅用于 `dispatch(action, owner)` 的一次性 closure；
- Search 的 `on_input` / `on_submit` / `on_select` 与 Bridge 的 `on_select` callback props 已进入 typed registry，不再由 view 制造 raw listener payload；
- Search item 与 Bridge case 使用稳定业务 id，过滤或重排不会改变同一交互的 registry identity；
- Todo 的开始/保存/取消编辑与 Lab 的发送回复已共享同一个 event-independent transition abstraction；domain action 保持完整，store action 顺序可观察；
- `on_local_*` 只保留给直接 model 更新、多步更新、复杂分支或尚未 action 化的组件流程；
- Todo、Lab、Route 迁移保留原 semantic name/path；Search、Bridge 则有意从 legacy raw payload 收敛到稳定 registry path。

### Runtime ownership 与恢复

- component state tree 已从业务 `model` 移出；
- `demo/runtimeframe.kk` 是 app model 与 runtime tree 的统一 owner；
- feature component 只返回 `vnode`，不再暴露 `(owner, vnode, effects, registry)` 四元组；
- 整棵 app tree 在一个 runtime handler 内渲染，由 `run_runtime_render(...)` 在线程边界读写状态树；
- feature 使用绝对 root scope，保持 HMR/localStorage snapshot path 不受 layout 移动影响；
- 业务模块已删除跨 feature key 读取/写入 child store 的 helper；scope/path API 只保留给 framework/runtime inspection 与 tests；
- 父组件不再读取子组件 local store 做汇总；跨组件真正需要的数据应提升为 domain state；
- 旧的 `demo/runtimebridge.kk` / `demo/runtimeowner.kk` 过渡层已经删除；
- snapshot 使用 `respo/runtime-snapshot|1` 顶层 envelope，entry 保持 path + schema + version + payload；decoder 兼容旧无 header 格式；
- ordinary child ownership marker 会进入 snapshot；feature 恢复后可继续判断 stale child，旧版无 marker 的孤立 entry 不做不安全的 path 推断；
- unknown/malformed 顶层版本回退空树；单个 malformed entry、unknown schema 和 entry version mismatch 只回退相关状态；
- replay store 使用 `respo/replay:<action-schema>` entry，从当前 `initial` 和 decoded component actions 恢复；
- key segment 使用无碰撞 canonical encoding；现有 slug/数字路径保持不变，旧版空串、下划线开头或保留字符 key 的 snapshot 允许一次性回退 initial state；
- `src/main.js` 在事件后合并保存，并在 HMR replacement、dispose、`pagehide` 前 flush；
- 同一 snapshot 同时支持开发时 JS 替换和普通页面的 localStorage 恢复。

### Unified action observation

- domain action 与 component store action 共用 `action_envelope`；
- envelope 只包含 `source + target + schema + version + payload`，不捕获 closure；
- typed dispatch 自动发出 observation，组件调用点不额外传 logger；
- runtime 可选择 capture 或 discard，browser host 当前输出同一条有序 action stream；
- tests 已覆盖一次 Todo edit 中 `domain -> component` 的顺序与双向 codec 校验；
- 当前语义是 intent observation，不自动持久化或 replay 外部副作用。

## 公共 API 分层

### 业务组件优先使用

```koka
div(children, class = ..., key = ...)
button(text, class = ..., click = ...)
input_text(value, input = ..., enter = ..., placeholder = ...)

feature_root(group, key) { ... }
feature_key()
feature_marker(name)
component(group, key) { ... }
components(items, group = ..., key = ..., render = ...)

snapshot_store(name = ..., state_codec = ..., action_codec = ..., reduce = ...)
replay_store(name = ..., action_codec = ..., replay = ..., reduce = ...)
use_store(spec, initial = ...)
state_effect(name = ..., deps = ..., action = ...)
on_store_click(name, action = ..., dispatch = ...)
on_store_input(name, action = ..., dispatch = ...)
on_action_click(name, action = ..., dispatch = ...)
on_action_input(name, action = ..., dispatch = ...)
on_action_enter(name, action = ..., dispatch = ...)
action_store_transition(action, dispatch = ..., store_action = ..., store = ..., store_when = ...)
on_local_click(name, handler)
on_local_input(name, handler)
on_local_enter(name, handler)
```

### Runtime/testing inspection 使用

```koka
read_store_state(tree, scope, spec, initial)
feature_node_key(group = ..., key = ...)
feature_dom_marker(group = ..., key = ..., name = ...)
```

这些显式 identity/tree API 不进入业务 view 或 domain reducer。

### Framework/runtime 内部使用

- `run_component(owner, group = ..., key = ..., render = ...)`，每棵 app tree 只安装一次；
- `reset_feature(group = ..., key = ...)`，由 integration lifecycle 清理持久 feature branch；
- `state_entry`、`state_slot`、raw tree operations；
- codec 编解码和 snapshot wire format；
- handler 安装和 runtime frame plumbing；
- raw listener payload 与 DOM delegated bridge。

业务 view 不应依赖这一层。

## 下一阶段

按用户风险与依赖顺序推进，不并行扩张公共 API：

### 1. 版本化 runtime snapshot（#17）

- 当前实现批次：完整 snapshot 已增加 `respo/runtime-snapshot|1` header，并兼容读取现有无 envelope 格式；
- unknown/malformed 顶层版本回退空树，malformed entry 与 entry 非法编码只丢弃自身，不阻断 app boot；
- entry 级 schema/version 校验保持不变，业务 view 不增加 snapshot 参数或 runtime import；
- Koka compatibility tests、旧 snapshot 浏览器启动、整页 reload 与真实 Vite HMR replacement 恢复均已完成验收。

### 2. 定义 effect cleanup 生命周期（#18）

- 为 component author 提供清晰的 setup + cleanup authoring shape；
- 明确 deps change、ordinary child unmount、feature reset 与 runtime replacement 的 cleanup 顺序；
- snapshot flush 先于旧 runtime cleanup，cleanup closure 不进入 snapshot；
- 用一个真实 demo capability、deterministic tests 与浏览器 HMR 回归验证。

### 3. 发布 agent-safe store/action surface（#19）

- 暴露可序列化的只读 catalog，不暴露 raw state entry、closure 或 tree write；
- action dispatch 必须通过已注册 codec 校验，并复用现有 typed reducer/observation 链路；
- 明确区分 domain action、ephemeral component action 与默认不可投递 capability；
- 自动 replay、完整权限 UI 和远程身份认证继续保持非目标。

### 持续约束

- component authoring surface 保持在 `core/action/state`，不增加只做转发的 facade；
- controlled component 继续使用“主 domain value 位置参数 + labelled callback/config props”；
- 显式 key/path/store inspection 只有在能移动真实实现且不产生单行 wrapper 时再拆；
- typed listener helper 只在出现第三个真实重复形态时扩展。

## GitHub 跟踪

issue、PR 及影响结论的进度更新统一使用中英双语：标题采用 `中文 / English`，正文分别写成完整的 `# 中文` 与 `# English` 章节，避免逐行混排，确保两部分都能独立用于跟踪。

- [#7 隐藏 feature identity 并移除跨组件 store path 协调 / Hide feature identity and remove cross-component store path coordination](https://github.com/Respo/explore-react.koka/issues/7)：已由 PR #10 合并；
- [#8 减少 typed store 样板代码并显式选择 replay 恢复 / Reduce typed store boilerplate with explicit replay recovery](https://github.com/Respo/explore-react.koka/issues/8)：已由 PR #14 合并；snapshot/replay recovery 选择与 Todo editor session 语义已落地；
- [#9 定义不可达 child component store 的生命周期清理 / Define lifecycle cleanup for unreachable child component stores](https://github.com/Respo/explore-react.koka/issues/9)：已由 PR #11 合并；
- [#12 简化组件事件中的 domain 与 local-store transition / Simplify domain and local-store transitions in component events](https://github.com/Respo/explore-react.koka/issues/12)：已由 PR #15 合并；四个真实调用点共享 event-independent transition，并覆盖 action 顺序与浏览器回归；
- [#13 发布渐进式组件作者 API / Publish a progressive-disclosure component authoring surface](https://github.com/Respo/explore-react.koka/issues/13)：已由 PR #16 合并；四概念 quick start、单页 author API 与 advanced module import 边界已落地；
- [#17 版本化 runtime snapshot 并定义兼容迁移 / Version runtime snapshots and define compatible migration](https://github.com/Respo/explore-react.koka/issues/17)：下一实现批次；先固定 snapshot envelope、legacy compatibility 与安全回退；
- [#18 定义组件 effect cleanup 生命周期 / Define the component effect cleanup lifecycle](https://github.com/Respo/explore-react.koka/issues/18)：排在 #17 之后，依赖明确的 HMR snapshot/boot 边界；
- [#19 发布 agent-safe store catalog 与校验 action dispatch / Publish an agent-safe store catalog and validated action dispatch](https://github.com/Respo/explore-react.koka/issues/19)：后续探索批次；在不暴露 raw runtime tree 的前提下服务 devtools/agents。

## 验证标准

每一轮重构至少验证：

1. `yarn test:koka` 通过；
2. `yarn build` 通过；
3. Todo 新增、编辑、保存、取消、切换、删除和 filter 正常；
4. Lab card expand/draft/send 正常；
5. 快速 input 后立即触发 click/Enter 不丢最后一次值；
6. HMR replacement 后 component store 能从最新 snapshot 恢复；
7. malformed/旧版本 snapshot 不导致 boot 失败；
8. listener registry 没有 duplicate id 或 semantic drift warning；
9. ordinary child unmount 会清理 store/effect/marker，整个 feature unmount 仍保留 snapshot；
10. replay editor 的重复 input 只保留最新 draft，finish/cancel 回到最新 `initial`，malformed/version mismatch 安全回退。

## 非目标

- SSR 或 hydration；
- 1:1 复刻 React internals；
- 为兼容旧的 codec-at-call-site API 保留长期包袱；
- 把 component snapshot 当作领域数据数据库；
- 在 component/runtime ownership 稳定前做大规模 DOM 微优化。
