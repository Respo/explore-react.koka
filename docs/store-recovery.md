# Typed store recovery

Respo 的组件作者始终使用同一种 reducer pair：

```koka
val (state, dispatch) = use_store(spec, initial = initial_state)
```

恢复策略只在 store 定义处选择。业务 view 不读取 snapshot、action log、scope 或 runtime tree。

## 两种恢复方式

| 构造器 | 持久内容 | 适用状态 | 组件作者需要提供 |
| --- | --- | --- | --- |
| `snapshot_store(...)` | 编码后的完整 state | 累积、toggle、复杂状态，或不能安全压缩的 reducer | state codec、action codec、reducer |
| `replay_store(...)` | 当前 session 内压缩后的 component actions | editor draft、wizard 当前步骤等天然有界 session | action codec、replay policy、reducer |

两者都保留显式 `name`、action schema/version 和纯 reducer。区别仅在 HMR/reload 后如何重建 state。

## Snapshot store

当任意历史 action 都可能影响当前值时，使用 snapshot：

```koka
pub val incident_local_store = snapshot_store(
  name = "incident",
  state_codec = incident_state_codec,
  action_codec = incident_action_codec,
  reduce = reduce_incident)
```

例如 counter increment、toggle 序列或长期累积集合不能通过删除旧 action 保持等价。不要为了使用 replay 而静默截断这类历史。

## Replay store

Todo editor 不再定义 state encode/decode。它只声明 action 如何组成一个可恢复 session：

```koka
pub val task_editor_store = replay_store(
  name = "editor",
  action_codec = task_editor_action_codec,
  replay = fn(action) {
    match action
      Begin_edit(_) -> Replay_start
      Change_draft(_) -> Replay_replace("draft")
      Finish_edit -> Replay_reset
      Cancel_edit(_) -> Replay_reset
  },
  reduce = reduce_task_editor)
```

`replay_action_mode` 的语义是：

- `Replay_start`：开始新 session，删除旧 session，只保留当前 action；
- `Replay_replace(slot)`：保留该静态 slot 最新的一次 action，再放到日志末尾；
- `Replay_reset`：结束 session，恢复时直接使用调用点的当前 `initial`。

slot 名称应是 store 定义中有限、稳定的语义名称，例如 `"draft"`、`"selection"`，不要使用用户输入或业务 id 动态制造无限 slot。

框架没有 `Replay_append`，也不会为了限制长度而丢弃最早 action。任意截断可能改变 reducer 结果；不能表示为 start/replace/reset 的状态应使用 `snapshot_store(...)`。

## 为什么 Finish 和 Cancel 使用 Reset

编辑结束以后，domain model 已经拥有保存后的标题，或者仍保留取消前的标题。下一次 render 会把这个值作为新的 `initial`：

```koka
use_store(
  task_editor_store,
  initial = Task_editor_state(False, item.title))
```

因此完成 session 后不应继续 replay 旧 draft。`Replay_reset` 清空当前 session，store 从最新 domain value 重新开始。

## Snapshot、HMR 与 lifecycle

Replay entry 使用 `respo/replay:<action-schema>` 和 action codec version。payload 只包含压缩后的 component action payload；恢复时逐个 decode，再用当前 reducer 从 `initial` 计算 state。

- malformed payload、schema mismatch 或 version mismatch 会回退 `initial`；
- ordinary child unmount 会连同 replay entry 一起 sweep；
- 整个 persistent feature 暂时不 render 时保留 replay entry；
- Vite HMR 和 `localStorage` 使用现有 component snapshot 通道，不建立第二棵业务状态树。

从 snapshot recovery 切换到 replay recovery 会改变 entry schema。旧 state snapshot 无法可靠反推出原 action，因此允许一次性回退 `initial`；新 replay snapshot 产生后，后续 HMR/reload 正常恢复。

### Runtime snapshot envelope

完整 runtime snapshot 的第一行是 `respo/runtime-snapshot|1`。这是 transport format version，与每个 store entry 自己的 schema/version 分开：顶层版本决定如何拆解 snapshot，entry version 决定某个 typed store 是否能恢复。

- 当前 decoder 继续读取旧的无 header、每行四字段 snapshot；下一次保存会自然写成 versioned envelope；
- unknown 或 malformed 顶层版本会把整棵 runtime tree 安全回退为空，再由 component 使用各自的 `initial`；
- 已识别格式中的单个 malformed entry 会被跳过，其他合法 entry 仍可恢复；
- 空 runtime tree 也编码为 header，而不是无版本的空字符串；传入空字符串仍表示“没有 snapshot”；
- `respo/effect` render metadata 不进入 snapshot，domain model 也不走这条持久化通道。

浏览器继续使用现有 `koka-respo:component-state:v1` localStorage key，以便发现升级前保存的值。wire format 的后续演进由 snapshot envelope 管理，不由业务 view 或 store 调用点管理。

## 与 action observation 的区别

Replay log 只属于一个明确选择 `replay_store(...)` 的 component store，并且只包含它自己的纯 typed actions。

统一的 `action_envelope` observation 仍是 intent stream：其中可能包含 domain action、confirm、request 或 timer workflow。框架不会把 observation stream 自动当成 replay log，也不会自动重放外部 effects。

## 选择检查表

优先选择 replay，只有当以下问题都回答为“是”：

1. reducer 是纯函数；
2. action 已有稳定 codec；
3. state 是一个有明确开始和结束的临时 session；
4. 高频更新可以按有限静态 slot 只保留最后一次；
5. session 结束后使用最新 `initial` 是正确语义。

否则使用 snapshot。恢复策略应服务于组件作者的清晰度和正确性，而不是为了少写 codec 强行改变状态语义。
