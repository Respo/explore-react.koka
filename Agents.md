# explore-react Developer Guide

这份文档不是零碎备忘录，而是重新上手这个仓库时的开发引导。目标是：先跑起来，再改 Koka 代码，再验证浏览器和测试链路，最后再扩展新的 demo。

## 先从哪里开始

第一次回到仓库时，优先按这个顺序走：

1. 先看 `package.json` 里的脚本，确认日常入口还是 `yarn dev`、`yarn build`、`yarn test:koka`。
2. 再看 `app.kk`，确认当前浏览器桥只暴露哪些 Koka 入口。
3. 然后看 `explore/react/*` 和 `demo/*` 的边界：前者是库，后者是 demo 和业务。
4. 开始改代码前，先跑一次 `yarn build`，确认自己不是站在坏状态上继续开发。

## 仓库结构

- 仓库根目录：就是 Koka 源码根目录，编译时直接把 repo root 当成模块搜索根。
- `app.kk`：浏览器入口，只暴露 boot、事件桥接和 runtime snapshot 导入导出。
- `explore/react/*`：核心 VDOM、typed component store、listener registry、render、diff/patch。这里尽量保持通用。
- `demo/*`：具体 demo、布局、组件、路由和测试辅助。
- `demo/runtimeframe.kk`：app 边界的 runtime owner，同时持有业务 model 和框架 state tree。
- `runtime/*`：只放 DOM 和系统边界的 FFI，不要把业务逻辑塞进来。
- `scripts/build-koka.mjs`：从仓库根目录调用 Koka，输出到 `src/generated/koka`。
- `scripts/test-koka.mjs`：从仓库根目录执行 `tests_main.kk`。
- `src/main.js`：Vite 主机入口，只负责挂接生成后的 Koka 导出。

## 日常开发命令

最常用的是下面这组：

```bash
yarn dev
yarn build
yarn check
yarn test:koka
```

分别表示：

- `yarn dev`：先编译 Koka，再启动 Vite。做 UI、交互、浏览器联调时优先用它。
- `yarn build:koka`：只重编译 Koka，适合只改 `.kk` 文件时快速验证生成产物。
- `yarn build`：Koka + Vite 全链路构建，改模块边界、入口导出、浏览器桥时先跑它。
- `yarn check`：Koka 构建 + Vite bundling 检查，适合看宿主层是不是也被带坏了。
- `yarn test:koka`：跑 Koka 侧快速测试，不依赖浏览器。

模块缓存或生成产物异常时，优先用这个最便宜的重置：

```bash
rm -rf .koka-build .koka-test && yarn build
```

如果需要直接绕过脚本看底层 Koka 命令，使用：

```bash
koka --target=jsnode --builddir=.koka-test --execute tests_main.kk
koka --target=jsweb --library --builddir=.koka-build --outputdir=./src/generated/koka --output=koka-app app.kk
```

## Koka 编译规则

这个仓库最容易出错的是模块搜索根。

- 编译 Koka 时，`cwd` 应该直接对齐到仓库根目录，否则像 `demo/model` 这样的导入可能找不到。
- 导入路径以仓库根为根：`import demo/model`，不要写 `import koka/demo/model`。
- 生成入口文件名不稳定，所以构建脚本靠扫描 `export function boot(` 找入口，不要手写猜测产物名。
- 浏览器桥应该保持很薄，目前只导出少量入口给宿主层，例如 `boot_with_snapshot`、点击/输入派发、路由派发和 snapshot 导出。

## Yarn 与 Vite 工作流

- 仓库使用 Yarn Berry，日常命令统一走 `yarn`，不要切回 npm。
- Vite 默认端口配置在 `vite.config.js`；要固定本地地址时可用：

```bash
yarn dev --host 127.0.0.1 --port 4173
```

- 如果端口被占用，Vite 会自动换端口，后续 `chrome-devtools` 要跟着实际端口走。
- 页面起来了但交互失效时，先检查 `src/generated/koka-entry.mjs` 与 `src/main.js`、`runtime/inline/dom.js` 的桥接变量名是否一致。

## Chrome DevTools 命令流程

这里要记的是实际命令，不是抽象描述。一个完整流程通常是：

```bash
yarn dev --host 127.0.0.1 --port 4173
chrome-devtools new_page http://127.0.0.1:4173/
chrome-devtools list_pages
chrome-devtools select_page <page_id>
chrome-devtools take_snapshot --filePath .tmp-devtools-snapshot.txt
chrome-devtools take_screenshot --fullPage --filePath .tmp-devtools-full.png
```

常用调试动作：

- 新开页面：`chrome-devtools new_page http://127.0.0.1:4173/`
- 列出现有页面：`chrome-devtools list_pages`
- 选择当前页面：`chrome-devtools select_page 7`
- 保存结构快照：`chrome-devtools take_snapshot --filePath .tmp-devtools-snapshot.txt`
- 保存整页截图：`chrome-devtools take_screenshot --fullPage --filePath .tmp-devtools-full.png`
- 如果已经拿到 snapshot 里的 `uid`，后续可继续用 `click`、`fill`、`press_key` 做交互回归。

浏览器检查时，优先关注：

- 首屏文案和面板数量是否是新版本，不是旧缓存。
- 事件委托属性是否还在：`data-k-click`、`data-k-input`、`data-k-enter`。
- 交互冒烟顺序是否还通：新增任务、回车提交、切换 done、切换 filter、删除、清空 completed。
- 大屏布局是否真的吃满宽度，而不是把信息挤进一条窄侧栏。

## 测试策略

默认先跑 Koka 测试，再跑浏览器。

- 纯逻辑、reducer、render、effect handler 优先放进 `yarn test:koka`。
- HTML 输出测试直接比较 `render_node(...)` 的字符串，适合做轻量 snapshot。
- `confirm_action` 这类效果，使用 handler 模拟接受/拒绝，不要依赖浏览器原生弹窗。
- `wait_ms` 这类 timer 效果，用 handler 记录延迟值，做“立即完成”的快速测试。
- 浏览器测试只验证桥接、真实 DOM patch 和端到端交互链路。

## 新增 Demo 的推荐步骤

现在仓库已经开始有顶层 route，后续加新 demo 建议按这个顺序：

1. 在 `demo/` 新建一个单独模块，例如 `mydemo.kk`。
2. 暴露一个顶层面板函数，例如 `my_demo_panel(model) : vnode`。
3. 在 `demo/model.kk` 里补 route 名称归一化和 route action。
4. 在 route bar 里加一个新 tab。
5. 在 `demo/layout.kk` 里把新 route 接进页面分发。
6. 如果 demo 有纯逻辑，就把测试加到 `demo/tests.kk` 或独立测试模块。

## 代码风格约定

- **不要写单行 accessor 包装函数**，例如：
  ```koka
  pub fun task_title(item : task) : string
    task/title(item)
  ```
  这类函数只是给 struct 字段起别名，拆得越多越难找逻辑。调用方直接内联 `task/title(item)` 或 `item.title`，保持代码密度。
- 只在以下情况才抽函数：有额外逻辑（条件、组合、副作用），或者跨模块需要稳定的公开接口名称。

## 组件本地状态约定（typed store + actions）

组件交互状态以 **typed store + serializable actions** 为默认方案。它保留 React reducer 的简单心智模型，同时满足 Koka 严格类型、HMR 和 snapshot 恢复需求。

- 业务组件用 `(state, dispatch) = use_store(spec, initial = ...)` 读取 reducer pair，不额外暴露 binding record。
- UI 事件优先用 `on_store_click(name, action = ..., dispatch = ...)` / `on_store_input(...)` 发送 typed action，不直接操作 state tree。
- domain action 事件优先用 `on_action_click(name, action = ..., dispatch = ...)` / `on_action_input(...)` / `on_action_enter(...)`，不要在每个 element 内重复 forwarding closure。
- 只有包含额外分支、组合更新或直接 model 输入的 handler 才使用 `on_local_*`。
- 一个 store 把 state 类型、action 类型、纯 reducer 和 versioned codecs 定义在一起；codec 只在 store 定义处出现，不传进组件调用。
- scope/path/slot/tree 属于 framework/runtime 细节。列表组件用 `components(items, group = ..., key = ..., render = ...)` 建立稳定 identity。
- app 集成层用 `run_component(owner, group = ..., key = ..., render = fn(owner) ...)`，不要重复嵌套 `run_stateful_component + component_root + fn()`。
- 高层 view component 保持一个主要 domain value 位置参数，其余 callback/config props 使用 labelled arguments，例如 `on_input = ...`、`on_submit = ...`、`on_select = ...`。
- 组件外协调状态时用 `current_store_state(...)` / `dispatch_store(...)` 这类 typed API；不要在业务模块复制 tree 编解码。
- action 必须可序列化，方便事件日志、恢复、回放，以及后续 agents/actions/store 工具链。

推荐形态：

```koka
val (Task_editor_state(editing, draft), dispatch_editor) = use_store(
  task_editor_store,
  initial = Task_editor_state(False, item.title))

input_text(
  draft,
  input = on_store_input(
    "draft-input",
    action = Change_draft,
    dispatch = dispatch_editor))

button(
  "Save",
  click = on_action_click(
    "save-edit",
    action = Save_task,
    dispatch = dispatch))
```

`state(...)` / `state_pair(...)` 可以用于没有业务 action 语义的简单实验，但新业务组件只要状态由用户事件更新，就优先定义 typed store。不要继续扩散显式 codec、hook index 或手工 path 的调用形式。

## Element 调用约定

- element 的主要内容保持第一个位置参数：容器传 `list<vnode>`，文本元素传 `string`。
- 常用 DOM 属性和事件压平为 labelled arguments，例如 `class = ...`、`key = ...`、`click = ...`、`input = ...`。
- 不使用 `attrs = {...}, children = ...` 这种嵌套记录写法。
- 少见 DOM 属性和事件才放进 `extra_attrs` / `extra_events` escape hatch。

```koka
div([
  strong(item.title, class = "task-title"),
  button("Edit", class = "button", click = edit_listener),
], key = item.id.show, class = "task-item")
```

## Runtime snapshot 与 HMR

- component runtime tree 不放回业务 `model`；app 边界通过 `runtime_frame` 持有。
- feature/view API 不得接收或返回 `list<state_entry>`；render transition 统一通过 `run_runtime_render(...)`。
- parent component 不读取 child local store 做业务汇总；确实需要上层观察的数据提升到 domain model，纯调试统计放到 framework inspector。
- component runners 必须串行操作 runtime host，不要把一个 stateful runner 嵌套在另一个 runner 的 render callback 内。
- snapshot entry 必须保留稳定 path、schema、version、payload；decoder 对 malformed payload、schema/version 不匹配安全回退。
- `src/main.js` 负责 localStorage 与 Vite HMR hand-off。修改浏览器桥时要验证 replacement 前 flush、dispose 和 `pagehide` 三条路径。
- snapshot 只是组件临时状态恢复机制，不替代业务数据持久化。

## Koka 常见易错点

- 跨模块使用的 `struct`、`effect`、公开函数要显式 `pub`，否则拆文件后很容易编到一半才报不可见。
- `--execute` 的测试脚本如果不在正确目录执行，模块解析会失败；优先把 `cwd` 对齐到仓库根目录。
- effect handler 很容易意外带出额外效果，例如在 handler 子句里做递归处理，把 `<div>` 或 `<local>` 混进签名；先写最小 handler，再做组合。
- snake_case 类型名的构造器不总是直觉，例如 `test_result` 对应 `Test_result`；找不到构造器时先怀疑这一层。
- 分支里的顺序语句尽量保持简单；如果解析器报意外语法，先把字符串拼装或中间计算抽成独立函数。
- FFI 只做 DOM 或系统边界；组件描述、状态、diff/patch 仍然保持在 Koka 内部。

## 遇到问题先看这里

- 构建失败：先检查是不是模块搜索根不对，再检查 `pub` 可见性和生成入口。
- 页面空白：检查 `src/generated/koka-entry.mjs` 是否重生成，以及 Vite 是否加载了新模块。
- 点击没反应：检查 `runtime/inline/dom.js` 的 delegated event 是否还在调用正确的全局桥。
- 地址栏 hash 和页面不一致：先看 route 是否在 commit 后同步回浏览器。
- 输入值不同步：检查 `sync_input` 是否在 commit 后执行。
- UI 显得花哨或浪费空间：优先调整信息密度、列宽和面板组织，而不是先把配色全部抹平。
