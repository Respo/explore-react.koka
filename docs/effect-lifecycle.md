# Effect lifecycle

# 中文

Respo 把“render 后执行一次工作”和“持有需要释放的外部资源”分成两个 API：

```koka
state_effect("focus-editor", [editing.show]) {
  if editing then dom_focus("draft") else ()
}

state_resource(
  name = "route-session",
  deps = [route_name],
  cleanup = fn() release_route_session(route_name),
  action = fn() start_route_session(route_name))
```

`state_effect(...)` 适合 focus、flash、日志等不需要释放资源的 render 后工作，并支持 Koka trailing-lambda。`state_resource(...)` 适合 event subscription、observer、timer handle、stream 或其他必须显式释放的资源。setup 与 cleanup 使用独立的 labelled arguments，避免让同一个严格类型 callback 同时返回 unit 或 cleanup function。

## 生命周期顺序

同一个 component boundary 内，`name` 是 effect 的稳定 identity，`deps` 决定是否更新：

1. 首次出现：DOM commit 完成后执行 setup，并登记 cleanup。
2. deps 不变：不执行 setup 或 cleanup。
3. deps 改变：旧 cleanup 恰好执行一次，再执行新 setup，并登记新 cleanup。
4. ordinary `component(...)` unmount：执行旧 cleanup，并删除 registry entry。
5. `reset_feature(...)`：清理整个 feature branch 对应的 live resources。
6. runtime dispose / HMR：先导出 snapshot，再执行旧 runtime 的全部 cleanup，最后 boot 新 runtime。

cleanup 抛出的异常会通过 host 的 `[explore-react effect]` 日志报告；它不会阻止下一个 setup 或新 runtime boot。setup 异常仍按正常 host error 处理，因为失败的 setup 不能假装已经安装成功。

## Persistent feature policy

`feature_root(...)` 暂时不 render（例如切换 route）时，snapshot 和 live resource 都保留。这里把 persistent feature 视为暂时隐藏，而不是 unmount；返回 route 时，同一 deps 不会重复安装资源。

如果资源只应在“可见”期间存在，请把 visibility 放入 deps，并在仍 mounted 的 component 中切换 setup/cleanup，或者由 integration boundary 显式调用 `reset_feature(...)`。不要仅为了释放资源而删除可恢复的 feature state。

## Snapshot 与 HMR

状态树只保存 `respo/effect` dependency metadata。cleanup closure 保存在旧 JavaScript runtime 的内存 registry 中，不会序列化到 snapshot 或 `localStorage`。

HMR 顺序固定为：

1. `exportStateSnapshot()`；
2. `disposeRuntime()`，安全执行旧 cleanup；
3. 安装新 bridge；
4. `bootWithSnapshot(...)`；
5. 新 runtime 根据恢复后的 render 重新 setup resources。

因此 typed component state 可以恢复，而 closure、DOM handle、listener 和其他旧模块资源不会跨 JavaScript replacement 泄漏。

# English

Respo separates post-render work from external resources that require explicit release:

```koka
state_effect("focus-editor", [editing.show]) {
  if editing then dom_focus("draft") else ()
}

state_resource(
  name = "route-session",
  deps = [route_name],
  cleanup = fn() release_route_session(route_name),
  action = fn() start_route_session(route_name))
```

Use `state_effect(...)` for focus, flash, logging, and other post-render work that has nothing to release; it supports Koka trailing-lambda syntax. Use `state_resource(...)` for event subscriptions, observers, timer handles, streams, and other resources that require explicit release. Separate labelled setup and cleanup arguments avoid forcing one strictly typed callback to return either unit or a cleanup function.

## Lifecycle order

Within one component boundary, `name` is the stable effect identity and `deps` controls replacement:

1. First appearance: run setup after DOM commit and register cleanup.
2. Unchanged deps: run neither setup nor cleanup.
3. Changed deps: run the old cleanup exactly once, then run the new setup and register its cleanup.
4. Ordinary `component(...)` unmount: run the old cleanup and remove its registry entry.
5. `reset_feature(...)`: release live resources for the complete feature branch.
6. Runtime dispose / HMR: export the snapshot first, dispose all old-runtime resources, then boot the new runtime.

A cleanup exception is reported through the host's `[explore-react effect]` log and cannot block the following setup or new-runtime boot. Setup failures keep normal host error behavior because a failed setup must not be treated as an installed resource.

## Persistent feature policy

When a `feature_root(...)` is temporarily absent, such as after route navigation, both its snapshot and live resources remain. A persistent feature is considered hidden rather than unmounted, so returning to the route with unchanged deps does not install the resource again.

If a resource should exist only while visible, include visibility in its dependencies and transition it while the component remains mounted, or let the integration boundary call `reset_feature(...)` explicitly. Do not discard recoverable feature state merely to release a resource.

## Snapshot and HMR

The state tree stores only `respo/effect` dependency metadata. Cleanup closures stay in an in-memory registry owned by the old JavaScript runtime; they are never serialized into the snapshot or `localStorage`.

HMR uses a fixed order:

1. `exportStateSnapshot()`;
2. `disposeRuntime()` safely runs old cleanup callbacks;
3. install the new bridges;
4. `bootWithSnapshot(...)`;
5. the new runtime sets resources up again from its restored render.

Typed component state can therefore recover while closures, DOM handles, listeners, and other old-module resources cannot leak across JavaScript replacement.
