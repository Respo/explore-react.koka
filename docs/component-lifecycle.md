# Component lifecycle and snapshot retention

Respo 的 component runtime 同时承担两件看似冲突的事：

- 普通 keyed child 消失以后，应释放只属于该实例的临时状态；
- persistent feature 暂时不渲染时，应保留状态，以支持 route 返回、Vite HMR 和 `localStorage` 恢复。

这两个需求由不同的 boundary 表达，不由业务 reducer 手工清理 path。

## Boundary 语义

| 写法 | 是否建立 identity | 本轮不再出现时 | 适用场景 |
| --- | --- | --- | --- |
| 普通 view helper | 否 | 无 lifecycle | 纯渲染拆分 |
| `component(group, key) { ... }` | 相对当前 feature 的 keyed identity | 当前 feature 完成本轮 render 后清理 | 条目、卡片、条件子树 |
| `components(items, ...)` | 每个 item 一个 keyed child | item 不再 render 时清理 | keyed list |
| `feature_root(group, key) { ... }` | 绝对 persistent identity | 整个 feature 未 render 时保留 | 页面级 feature、可复用 panel |
| `reset_feature(group, key)` | 显式针对 feature | 立即清除整棵 feature branch | app-owned singleton 的生命周期重置 |

因此，`component(...)` 更接近 React child 的 mount/unmount；`feature_root(...)` 则是 Respo 为 HMR 和 route 恢复额外提供的持久边界。

## Runtime 如何清理

业务代码仍然只写正常的 component boundary：

```koka
feature_root("todo", key) {
  ul(components(
    visible_tasks,
    group = "tasks",
    key = fn(item) item.id.show,
    render = task_item_view))
}
```

runtime 在内部完成以下步骤：

1. `feature_root(...)` 开始一次独立的 visitation pass。
2. 每个 `component(...)` 登记自己的稳定 scope。
3. runtime 写入 `respo/component-scope` marker；marker 是 snapshot metadata，不是业务 state。
4. feature render 完成后，将本轮访问集合与旧 marker 比较。
5. 未再次访问的普通 child 会连同 state、effect metadata 和 marker 一起删除。
6. 当前 feature 根自己的 state 不参与这次 child sweep。

marker 使用 feature 内部的保留路径保存，业务组件不读取、构造或修改它。

## 为什么 feature 未渲染时不会丢状态

只有真正进入某个 `feature_root(...)` 并完成 render，runtime 才能判断它的 child 是否已经 unmount。如果 route 切换后整个 feature 没有执行，本轮就不会对该 feature 做 sweep，它的 marker 和 store entry 会原样留在 runtime tree 中。

当 feature 再次出现时：

- 同一个 `group + key` 恢复原 scope；
- 当前仍存在的 child 重新登记；
- 已经永久消失的旧 child 在这次 render 结束时被回收。

嵌套 `feature_root(...)` 维护自己的 visitation pass，不受外层普通 child 集合影响。

## 对组件作者的影响

### Filter 和条件分支

如果当前 feature 仍在 render，但某个普通 child 因 filter 或条件分支消失，它会被视为 unmount，本地 store 会清除。这与 React keyed child 的行为一致。

如果希望隐藏后仍保留值，有三个选择：

- 保持 child mounted，只改变可见样式；
- 把需要长期保留的数据提升为 domain state；
- 只有当它确实是独立、可持久恢复的 feature 时，才提升为 `feature_root(...)`。

不要仅为了保留一个 input draft 就滥用 persistent feature。

### Key 的责任

同一 feature 内，`group + key` 必须稳定且唯一。复用同一个 key 表示复用同一个 component identity；业务实体已经变化时，应使用新的 key。

### 删除业务数据

domain reducer 只删除 domain entity，不再调用 store/path 清理 API。删除后发生的下一次 render 会让对应 keyed child 自动 unmount 并释放 runtime state。

### App-owned singleton

Dialog overlay 这类全局 singleton 在关闭或 kind 改变时，可以由 integration boundary 调用 `reset_feature(...)`。这是 feature lifecycle，不是普通业务 reducer 跨组件写状态。

## Snapshot 与 HMR

`respo/component-scope` marker 会随 state entry 一起进入 snapshot，因此 HMR 或整页 reload 后，runtime 仍然知道哪些 entry 属于普通 keyed child。`respo/effect` dependency entry 仍然不会持久化；effect 会在新 runtime 中重新建立。

runtime snapshot 使用 `respo/runtime-snapshot|1` 顶层 header。decoder 仍兼容旧的无 header snapshot；unknown 顶层版本安全回退为空树，已识别格式中的单个 malformed entry 只丢弃自身。顶层 transport version 不替代 entry schema/version，两层分别负责 wire format 和 typed store recovery。

旧版本 snapshot 没有 lifecycle marker。当前仍然渲染的 child 会在下一次 render 自动获得 marker；旧 snapshot 中已经孤立、且从未再次出现的 entry 无法可靠推断归属，因此不会用 path 猜测并删除。显式 feature reset 或后续 snapshot 版本迁移可以处理这类历史数据。

Snapshot 仍然只是临时 UI 状态的 best-effort 恢复机制，不替代 domain persistence。

## 当前测试覆盖

- snapshot encode/decode 后，未访问 child 被清理，仍访问 child 保留；
- 整个 feature 暂时未渲染时，child state 跨 snapshot 保留；
- Todo `Clear done` 与 `Remove` 都会释放对应 editor store、effect metadata 和 marker；
- Todo/Lab 多实例 feature 的 state 和 listener identity 继续隔离；
- HMR 与 `localStorage` 恢复链路继续保留 persistent feature state。

effect metadata 被删除时，runtime 会调度对应 live resource cleanup。依赖变化、ordinary child unmount、feature reset 与 HMR dispose 的完整顺序见 [effect lifecycle](effect-lifecycle.md)。
