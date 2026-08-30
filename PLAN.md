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
- action、dispatch 使用 labelled arguments，在 element 调用点保持可读；
- Todo、Lab、Route 已移除仅用于 `dispatch(action, owner)` 的一次性 closure；
- Search 的 `on_input` / `on_submit` / `on_select` 与 Bridge 的 `on_select` callback props 已进入 typed registry，不再由 view 制造 raw listener payload；
- Search item 与 Bridge case 使用稳定业务 id，过滤或重排不会改变同一交互的 registry identity；
- `on_local_*` 只保留给直接 model 更新、分支逻辑或尚未 action 化的组件流程；
- 同一事件需要同时发送 domain intent 和更新自身 store 时使用 `on_local_*`；Todo `Save_task(title)` 与 Lab `Send_reply(id, message)` 已采用这种完整 action；
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
- snapshot 使用 path + schema + version + payload；
- ordinary child ownership marker 会进入 snapshot；feature 恢复后可继续判断 stale child，旧版无 marker 的孤立 entry 不做不安全的 path 推断；
- malformed snapshot、unknown schema 和 version mismatch 会安全回退；
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

### 1. 收紧 store schema 与迁移策略

- 为 snapshot format 增加明确的顶层版本，而不只依赖 entry version；
- 梳理 state/action codec 的升级路径和兼容窗口；
- 评估是否提供框架级 codec combinators，减少 feature 手写 encode/decode；
- 保持 decoder 失败时回退 initial state，不让单个坏 entry 阻断 boot。

### 2. 评估 replay authoring 与权限策略

- Todo editor 已用显式 start/replace/reset policy 验证 session 型 replay；下一步先按 #8 的使用者标准评估定义规模与 HMR 行为，再决定是否推广；
- 只有天然有界 session 使用 component replay，不能安全压缩的 store 保持 snapshot；
- 外部 effect action 默认只允许 inspect，replay 需要 capability/permission；
- 定义 confirmation、request、timer 等 effect 的 recorded response 与去重策略；
- agent/domain action log persistence 与 scoped component replay entry 分开版本、权限和保留周期；
- devtools/agents 只能通过已注册 codec 解码和投递，不能写 raw state tree。

### 3. 拆分 component facade 与 runtime/testing API

- 将普通组件需要的 `component/components/use_store/state_effect/on_*` 收敛到 facade；
- 将 runner、registry、snapshot 与 tree inspection 移到 runtime/testing 模块；
- opaque feature identity 已进入 `feature_root`；下一步把显式 key/path inspection API 物理拆到 runtime/testing module；
- 为 controlled component 固定“主 domain value 位置参数 + labelled callback/config props”的签名模板，避免每个 feature 再造 props adapter；
- scope 计算只保留在确有跨组件协调的 state 模块；
- reducer、codec、store spec 尽量同模块定义，view 只 import typed surface；
- typed action listener 后续只在出现第三种重复事件形态时扩 API。

### 4. 完善 effect 生命周期

- 重新评估 `state_effect(...)` cleanup 契约；
- effect metadata 已跟随 ordinary component identity 执行 unmount sweep；下一步定义真正的 cleanup callback 契约；
- HMR 前确认旧 runtime 的 cleanup、snapshot flush 和新 runtime boot 顺序；
- 继续保持 browser host 只负责能力实现，不接管 feature workflow。

### 5. Devtools / agent-facing store surface

- 暴露只读的 store catalog：scope、schema、version 和可显示的 state；
- action dispatch 必须通过已注册 codec 校验；
- 区分 domain action 与 ephemeral component action；
- 给敏感或不可重放 action 增加 capability/permission 边界；
- 在工具协议稳定前，不把 runtime tree 的内部 wire format 当成公共 API。

## GitHub 跟踪

- [#7 Hide feature identity and remove cross-component store path coordination](https://github.com/Respo/explore-react.koka/issues/7)：已由 PR #10 合并；
- [#8 Reduce typed store boilerplate with explicit replay recovery](https://github.com/Respo/explore-react.koka/issues/8)：当前实现批次；以 Todo editor 的定义成本与恢复体验作为是否推广的标准；
- [#9 Define lifecycle cleanup for unreachable child component stores](https://github.com/Respo/explore-react.koka/issues/9)：已由 PR #11 合并；
- [#12 Simplify domain and local-store transitions in component events](https://github.com/Respo/explore-react.koka/issues/12)：等待 #8 明确 session 完成语义后再评估公共 abstraction；
- [#13 Publish a progressive-disclosure component authoring surface](https://github.com/Respo/explore-react.koka/issues/13)：在 recovery API 稳定后整理 quick start、authoring API 与 module 边界。

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
