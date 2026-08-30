# Domain 与 component-store transitions

# 中文

组件事件通常只需要发送一种 action：domain intent 使用 `on_action_*`，component-local update 使用 `on_store_*`。只有当一次用户操作必须同时提交完整的业务 intent，并结束或推进当前组件 session 时，才需要组合两者。

## 推荐写法

`action_store_transition(...)` 构造一个与 DOM event 无关的 typed handler：

```koka
val save_edit = action_store_transition(
  Save_task(draft),
  dispatch = dispatch,
  store_action = Finish_edit,
  store = dispatch_editor,
  store_when = draft != "")

input_text(draft, enter = on_local_enter("save-edit", save_edit))
button("Save", click = on_local_click("save-edit", save_edit))
```

domain action 保留组件当前值，因此 reducer、日志、恢复工具或未来 agent 不需要读取 child store。click 与 Enter 复用同一个 transition，不需要 `on_action_and_store_click`、`on_action_and_store_enter` 之类的 helper 家族。

## 顺序契约

1. `dispatch(action, owner)` 总是先运行，并发出 domain action observation。
2. `store_when` 为 `True` 时，`store(store_action)` 随后运行，并发出 component action observation。
3. `store_when` 为 `False` 时，只跳过 component action；domain intent 仍然发送。
4. 返回值始终是 domain dispatch 产生的新 owner；component store 不会被 domain reducer 读取或修改。

observation 表示 intent 已发送，并不承诺 reducer 或外部 effect 成功。只有当组件能够在 render 时明确判断是否应该推进本地 session，才使用 `store_when`。

## 选择规则

| 事件形态 | API |
| --- | --- |
| 只发送 domain action | `on_action_click/input/enter(...)` |
| 只发送 component-store action | `on_store_click/input(...)` |
| 一个 domain action，随后至多一个 store action | `action_store_transition(...)` + `on_local_click/enter(...)` |
| 多个 store actions、依赖 effect response、复杂分支或直接修改 model | 手写 `on_local_*` handler |

不要把 confirm、request、timer 或 service response 隐藏进 transition。需要这些能力时，让 domain workflow 显式拥有 effect，并根据明确的业务结果设计后续状态。

# English

Most component events send only one kind of action: use `on_action_*` for a domain intent and `on_store_*` for a component-local update. Combine them only when one user operation must submit a complete business intent and then finish or advance the current component session.

## Preferred form

`action_store_transition(...)` builds a typed handler that is independent of the DOM event:

```koka
val save_edit = action_store_transition(
  Save_task(draft),
  dispatch = dispatch,
  store_action = Finish_edit,
  store = dispatch_editor,
  store_when = draft != "")

input_text(draft, enter = on_local_enter("save-edit", save_edit))
button("Save", click = on_local_click("save-edit", save_edit))
```

The domain action carries the current component value, so reducers, logs, recovery tools, and future agents never need to read the child store. Click and Enter reuse the same transition; the framework does not grow an `on_action_and_store_click` / `on_action_and_store_enter` helper family.

## Ordering contract

1. `dispatch(action, owner)` always runs first and emits the domain action observation.
2. When `store_when` is `True`, `store(store_action)` runs next and emits the component action observation.
3. When `store_when` is `False`, only the component action is skipped; the domain intent is still sent.
4. The returned value is always the new owner produced by the domain dispatch. The domain reducer never reads or mutates the component store.

An observation means that an intent was sent; it does not promise that a reducer or external effect succeeded. Use `store_when` only when the component can decide at render time whether its local session should advance.

## Decision guide

| Event shape | API |
| --- | --- |
| Domain action only | `on_action_click/input/enter(...)` |
| Component-store action only | `on_store_click/input(...)` |
| One domain action followed by at most one store action | `action_store_transition(...)` + `on_local_click/enter(...)` |
| Multiple store actions, an effect response, complex branching, or direct model mutation | A handwritten `on_local_*` handler |

Do not hide confirm, request, timer, or service responses inside this transition. Keep those capabilities explicit in the domain workflow and design later state changes around an explicit business result.
