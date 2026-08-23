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

- root 和 child 边界由 `component_root(...)` / `component_in(...)` 表达；
- 列表统一使用 `components(items, group = ..., key = ..., render = ...)`；
- 业务组件不再手工拼装 listener/effect/store path；
- state、effect 和 named listener 共享稳定的 keyed component scope。

### Typed component store

- `store_spec<s,a>` 将 state codec、action codec 和纯 reducer 组合在一起；
- 组件调用收敛为 `use_store(spec, initial = ...)`；
- `on_store_click(...)` / `on_store_input(...)` 直接发 typed action；
- 组件外协调通过 `current_store_state(...)` / `dispatch_store(...)`；
- Todo editor 与 Lab incident local state 已完成迁移；
- codec、slot 和 tree 编解码不再出现在普通 view 调用点。

### Runtime ownership 与恢复

- component state tree 已从业务 `model` 移出；
- `demo/runtimeframe.kk` 是 app model 与 runtime tree 的统一 owner；
- 旧的 `demo/runtimebridge.kk` / `demo/runtimeowner.kk` 过渡层已经删除；
- snapshot 使用 path + schema + version + payload；
- malformed snapshot、unknown schema 和 version mismatch 会安全回退；
- `src/main.js` 在事件后合并保存，并在 HMR replacement、dispose、`pagehide` 前 flush；
- 同一 snapshot 同时支持开发时 JS 替换和普通页面的 localStorage 恢复。

## 公共 API 分层

### 业务组件优先使用

```koka
div(children, class = ..., key = ...)
button(text, class = ..., click = ...)
input_text(value, input = ..., enter = ..., placeholder = ...)

component_root(group, key, render)
component_in(group, key, render)
components(items, group = ..., key = ..., render = ...)

use_store(spec, initial = ...)
state_effect(name = ..., deps = ..., action = ...)
on_store_click(name, binding, action)
on_store_input(name, binding, to_action)
on_local_click(name, handler)
on_local_input(name, handler)
on_local_enter(name, handler)
```

### Feature coordination 可以使用

```koka
current_store_state(scope, spec, initial)
dispatch_store(scope, spec, initial, action)
clear_store_state(scope, spec)
```

这些 API 仍然 typed，但调用方必须有真实的跨组件协调需求。

### Framework/runtime 内部使用

- `state_entry`、`state_slot`、raw tree operations；
- codec 编解码和 snapshot wire format；
- registry merge、handler 安装和 runtime frame plumbing；
- raw listener payload 与 DOM delegated bridge。

业务 view 不应依赖这一层。

## 下一阶段

### 1. 收紧 store schema 与迁移策略

- 为 snapshot format 增加明确的顶层版本，而不只依赖 entry version；
- 梳理 state/action codec 的升级路径和兼容窗口；
- 评估是否提供框架级 codec combinators，减少 feature 手写 encode/decode；
- 保持 decoder 失败时回退 initial state，不让单个坏 entry 阻断 boot。

### 2. 统一 action observation

- 让 app action 与 component store action 可以进入统一的可选日志；
- 日志只记录 serializable envelope，不捕获 closure；
- 为 tests、devtools 和 agents 提供相同的 inspect/replay 输入；
- 明确 replay 时 browser effects 的处理策略，避免重复执行外部副作用。

### 3. 进一步精简 feature 辅助函数

- 删除只转发 struct accessor 或只包装一次 framework API 的 helper；
- scope 计算只保留在确有跨组件协调的 state 模块；
- reducer、codec、store spec 尽量同模块定义，view 只 import typed surface；
- 如果相同 codec 样板在第三处出现，再提炼 framework combinator，避免为两个案例过早抽象。

### 4. 完善 effect 生命周期

- 重新评估 `state_effect(...)` cleanup 契约；
- 让 effect 的 component identity 与 snapshot state identity 保持一致；
- HMR 前确认旧 runtime 的 cleanup、snapshot flush 和新 runtime boot 顺序；
- 继续保持 browser host 只负责能力实现，不接管 feature workflow。

### 5. Devtools / agent-facing store surface

- 暴露只读的 store catalog：scope、schema、version 和可显示的 state；
- action dispatch 必须通过已注册 codec 校验；
- 区分 domain action 与 ephemeral component action；
- 给敏感或不可重放 action 增加 capability/permission 边界；
- 在工具协议稳定前，不把 runtime tree 的内部 wire format 当成公共 API。

## 验证标准

每一轮重构至少验证：

1. `yarn test:koka` 通过；
2. `yarn build` 通过；
3. Todo 新增、编辑、保存、取消、切换、删除和 filter 正常；
4. Lab card expand/draft/send 正常；
5. 快速 input 后立即触发 click/Enter 不丢最后一次值；
6. HMR replacement 后 component store 能从最新 snapshot 恢复；
7. malformed/旧版本 snapshot 不导致 boot 失败；
8. listener registry 没有 duplicate id 或 semantic drift warning。

## 非目标

- SSR 或 hydration；
- 1:1 复刻 React internals；
- 为兼容旧的 codec-at-call-site API 保留长期包袱；
- 把 component snapshot 当作领域数据数据库；
- 在 component/runtime ownership 稳定前做大规模 DOM 微优化。
