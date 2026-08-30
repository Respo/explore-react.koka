# Component quick start

# 中文

Respo 的日常组件代码只需要按顺序理解四件事：elements、keyed components、typed stores/actions 和 effects。下面用一个 FAQ feature 把它们串在一起。

## 1. 先写普通 view function

element 的主要内容保持第一个位置参数，样式、key 和事件使用 labelled arguments：

```koka
import explore/react/core

fun faq_answer(text : string) : vnode
  p(text, class = "faq-answer")
```

普通 function call 只负责拆分渲染，不创建组件 identity。没有 local state 的 helper 保持普通函数即可。

## 2. 定义 typed store 与 serializable action

store 把 state、action、纯 reducer 和恢复方式定义在一起。这个 disclosure 只有一个 toggle action，所以使用内置 bool codec 的 snapshot store：

```koka
import explore/react/action
import explore/react/state

type disclosure_action
  Toggle_disclosure

val disclosure_action_codec : action_codec<disclosure_action> = Action_codec(
  schema = "guide/disclosure-action",
  version = 1,
  decode = fn(version, payload) {
    if version == 1 && payload == "t" then Just(Toggle_disclosure) else Nothing
  },
  encode = fn(_action) "t")

val disclosure_store : store_spec<bool,disclosure_action> = snapshot_store(
  name = "open",
  state_codec = bool/state_codec,
  action_codec = disclosure_action_codec,
  reduce = fn(open, _action) not(open))
```

action schema/version 保持显式，方便 HMR 恢复、日志和未来 agent tooling。恢复方式只在 store 定义处选择；view 始终只拿 reducer pair。

## 3. 在组件中使用 state/dispatch pair

```koka
struct faq_item(id : string, question : string, answer : string)

fun faq_item_view(item : faq_item)
  val (open, dispatch) = use_store(disclosure_store, initial = False)
  state_effect(
    name = "log-open",
    deps = [open.show],
    action = fn() println(item.question ++ ": " ++ open.show))
  article([
    button(
      item.question,
      class = "faq-question",
      click = on_store_click(
        "toggle",
        action = Toggle_disclosure,
        dispatch = dispatch)),
    if open then faq_answer(item.answer) else span(""),
  ], key = item.id, class = "faq-item")
```

`use_store(...)` 返回熟悉的 `(state, dispatch)`。用户事件发送 typed action；`state_effect(...)` 用稳定 name 和 deps 描述 render 后的 effect。

## 4. 用 keyed boundary 组成 feature

```koka
fun faq_panel(items : list<faq_item>, key : string = "panel")
  feature_root("faq", key) {
    section([
      h2("Frequently asked questions"),
      div(components(
        items,
        group = "items",
        key = fn(item) item.id,
        render = faq_item_view)),
    ], key = feature_key(), class = "faq-panel")
  }
```

`components(...)` 给每个 item 建立稳定 keyed child；删除或过滤 item 等同于 unmount。`feature_root(...)` 是页面级 persistent boundary，route 暂时离开或 JavaScript hot replacement 时可以保留 feature snapshot。trailing-lambda 让 lifecycle boundary 与普通 helper call 在视觉上明显不同。

## 下一步

- [Component author API](component-authoring.md)：一页内查看推荐 surface 和选择规则。
- [Store recovery](store-recovery.md)：何时选择 snapshot_store 或 replay_store。
- [Component lifecycle](component-lifecycle.md)：ordinary child 与 persistent feature 的清理/保留语义。
- [Action/store transitions](action-store-transitions.md)：同一事件如何协调 domain intent 与 component store。

# English

Everyday Respo component code can be learned as four concepts in order: elements, keyed components, typed stores/actions, and effects. The following FAQ feature combines all four.

## 1. Start with an ordinary view function

Keep primary element content positional and use labelled arguments for styling, keys, and events:

```koka
import explore/react/core

fun faq_answer(text : string) : vnode
  p(text, class = "faq-answer")
```

An ordinary function call only extracts rendering. A helper without local state does not need component identity.

## 2. Define a typed store and serializable action

A store groups its state, action, pure reducer, and recovery choice. This disclosure has one toggle action, so it uses a snapshot store with the built-in bool codec:

```koka
import explore/react/action
import explore/react/state

type disclosure_action
  Toggle_disclosure

val disclosure_action_codec : action_codec<disclosure_action> = Action_codec(
  schema = "guide/disclosure-action",
  version = 1,
  decode = fn(version, payload) {
    if version == 1 && payload == "t" then Just(Toggle_disclosure) else Nothing
  },
  encode = fn(_action) "t")

val disclosure_store : store_spec<bool,disclosure_action> = snapshot_store(
  name = "open",
  state_codec = bool/state_codec,
  action_codec = disclosure_action_codec,
  reduce = fn(open, _action) not(open))
```

The action schema/version remains explicit for HMR recovery, logging, and future agent tooling. Recovery is selected only at the store definition; the view always receives the same reducer pair.

## 3. Use the state/dispatch pair in a component

```koka
struct faq_item(id : string, question : string, answer : string)

fun faq_item_view(item : faq_item)
  val (open, dispatch) = use_store(disclosure_store, initial = False)
  state_effect(
    name = "log-open",
    deps = [open.show],
    action = fn() println(item.question ++ ": " ++ open.show))
  article([
    button(
      item.question,
      class = "faq-question",
      click = on_store_click(
        "toggle",
        action = Toggle_disclosure,
        dispatch = dispatch)),
    if open then faq_answer(item.answer) else span(""),
  ], key = item.id, class = "faq-item")
```

`use_store(...)` returns the familiar `(state, dispatch)` pair. User events send typed actions; `state_effect(...)` describes a post-render effect with a stable name and dependencies.

## 4. Compose a feature with keyed boundaries

```koka
fun faq_panel(items : list<faq_item>, key : string = "panel")
  feature_root("faq", key) {
    section([
      h2("Frequently asked questions"),
      div(components(
        items,
        group = "items",
        key = fn(item) item.id,
        render = faq_item_view)),
    ], key = feature_key(), class = "faq-panel")
  }
```

`components(...)` creates a stable keyed child for every item; removing or filtering an item is an unmount. `feature_root(...)` is a page-level persistent boundary that can retain its feature snapshot across temporary route absence or JavaScript hot replacement. Trailing-lambda syntax makes lifecycle boundaries visually distinct from ordinary helper calls.

## Next steps

- [Component author API](component-authoring.md): the preferred surface and decision rules on one page.
- [Store recovery](store-recovery.md): when to choose snapshot_store or replay_store.
- [Component lifecycle](component-lifecycle.md): cleanup and retention for ordinary children and persistent features.
- [Action/store transitions](action-store-transitions.md): coordinating a domain intent and component store in one event.
