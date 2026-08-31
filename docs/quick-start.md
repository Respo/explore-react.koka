# Component quick start

# 中文

第一条成功路径不是从 browser runtime 开始，而是运行一个真实组件：

```bash
yarn example:first-component
```

命令会编译并执行 [示例组件](../examples/first_component/component.kk)，再在内存中触发一次注册的 click listener。成功输出在一屏内包含：

```text
Initial UI: ... State: closed ... Show answer ...
Typed action: Toggle_disclosure example/disclosure-action@1 payload=toggle
Updated UI: ... State: open ... Hide answer ...
```

这是教程唯一的实现来源；文档不再复制另一份 FAQ 代码。组件文件只使用：

```koka
import explore/react
```

从该文件按顺序阅读四个概念即可：

1. `disclosure_action` 和 `disclosure_action_codec`：每个用户 intent 都是可序列化 typed action。
2. `disclosure_store`：把 state、codec、reducer 与 snapshot recovery 放在一起。
3. `use_store(..., initial = False)`：返回熟悉的 `(state, dispatch)` pair。
4. `feature_root(...)` 和 `on_store_click(...)`：声明生命周期边界，并把点击发送为 `Toggle_disclosure`。

[执行 host](../examples/first_component/main.kk) 故意单独放在 advanced integration 边界：它才导入 renderer、inspection、runtime 和 state helpers，用来渲染、查找 listener、运行 action、再次 render。普通组件无需导入这些模块。

## 下一步

- [Component author API](component-authoring.md)：一页内查看推荐 surface 和选择规则。
- [Store recovery](store-recovery.md)：何时选择 snapshot_store 或 replay_store。
- [Component lifecycle](component-lifecycle.md)：ordinary child 与 persistent feature 的清理/保留语义。
- [Effect lifecycle](effect-lifecycle.md)：effect/resource 的 setup、cleanup 与 HMR 顺序。
- [Action/store transitions](action-store-transitions.md)：同一事件如何协调 domain intent 与 component store。

# English

The first success path does not start with the browser runtime. Run one real component:

```bash
yarn example:first-component
```

The command compiles and executes the [example component](../examples/first_component/component.kk), then triggers one registered click listener in memory. Its one-screen success output includes:

```text
Initial UI: ... State: closed ... Show answer ...
Typed action: Toggle_disclosure example/disclosure-action@1 payload=toggle
Updated UI: ... State: open ... Hide answer ...
```

This is the tutorial's only implementation source; the documentation no longer copies a second FAQ implementation. The component file uses only:

```koka
import explore/react
```

Read the file in this order to learn four concepts:

1. `disclosure_action` and `disclosure_action_codec`: each user intent is a serializable typed action.
2. `disclosure_store`: state, codec, reducer, and snapshot recovery belong together.
3. `use_store(..., initial = False)`: returns the familiar `(state, dispatch)` pair.
4. `feature_root(...)` and `on_store_click(...)`: declare the lifecycle boundary and send `Toggle_disclosure` for the click.

The [executable host](../examples/first_component/main.kk) deliberately lives at the advanced-integration boundary. It alone imports renderer, inspection, runtime, and state helpers to render, find the listener, run the action, and render again. Ordinary components do not need those modules.

## Next steps

- [Component author API](component-authoring.md): recommended surface and selection rules on one page.
- [Store recovery](store-recovery.md): when to choose snapshot_store or replay_store.
- [Component lifecycle](component-lifecycle.md): cleanup/preservation semantics for ordinary children and persistent features.
- [Effect lifecycle](effect-lifecycle.md): effect/resource setup, cleanup, and HMR order.
- [Action/store transitions](action-store-transitions.md): coordinate a domain intent and component store in one event.
