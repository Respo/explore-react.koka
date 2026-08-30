module demo/effectspanel

import demo/dialogs
import demo/model
import demo/tests/support
import demo/shared
import explore/react/core
import explore/react/state

fun tiny_task_list(key : string, tasks : list<task>) : <div> vnode
  if is-empty(tasks) then p("None", class = "empty") else ul(map(tasks, fn(item) li_text(item.title, key = "tiny-" ++ task/id(item).show)), key = key, class = "tiny-list")

fun effect_case(title : string, detail : string, body : vnode) : vnode
  article([
    h3(title, class = "case-title"),
    p(detail, class = "case-detail"),
    body,
  ], key = title, class = "case-item")

fun case_detail(result_name : string, empty_key : string, detail_key : string, empty_text : string, results : list<test_result>) : <div> vnode
  match find(results, fn(item) test_result/name(item) == result_name)
    Nothing -> p(empty_text, key = empty_key, class = "empty")
    Just(item) -> p(test_result/detail(item), key = detail_key, class = "mono")

fun core_effect_cases(item : model) : <div> list<vnode>
  val active = tasks_for("active", item.tasks)
  val done = tasks_for("done", item.tasks)
  [
    effect_case("Confirm", "`confirm_action` is handled by the browser in app mode and by tests in-process.", p("Try Remove or Clear done in the todo panel.", class = "mono")),
    effect_case("Ambient filter", "The reducer stays unchanged while handlers project active or done subsets.", div([
      div([
        strong("Active"),
        tiny_task_list("active-list", active),
      ], class = "mini-panel"),
      div([
        strong("Done"),
        tiny_task_list("done-list", done),
      ], class = "mini-panel"),
    ], class = "preview-grid")),
  ]

fun route_effect_cases(item : model, results : list<test_result>) : app_view list<vnode>
  if item.route_name == "effects-dialogs" then
    [effect_case(
      "Dialog overlays",
      "Inspired by the MoonBit and Rust explore-react demos: trigger controlled alert, prompt, dialog, and drawer surfaces without leaving the app tree.",
      component("dialogs", "demo") { dialog_demo_case(item) })]
  else if item.route_name == "effects-workflow" then
    [effect_case("Workflow lab", "The richer demo composes `wait_ms`, mocked server fetch/send, and an ambient operator identity into one deterministic workflow.", case_detail("Workflow sync captures waits", "workflow-empty", "workflow-detail", "Workflow case unavailable.", results))]
  else if item.route_name == "effects-state" then
    [effect_case("Local state tree", "Per-card drafts and expand/collapse flags live in a keyed state tree instead of leaking into the main domain snapshot.", case_detail("State tree semantic local state", "local-state-empty", "local-state-detail", "Local state case unavailable.", results))]
  else if item.route_name == "effects-timer" then
    [effect_case("Timer", "`wait_ms` is handled without real time passing, so the case stays deterministic.", case_detail("Timer simulation", "timer-empty", "timer-detail", "Timer case unavailable.", results))]
  else
    core_effect_cases(item)

fun effects_panel_note(route_name : string) : string
  if route_name == "effects-dialogs" then "Dialog overlays get their own route so alert, prompt, dialog, and drawer interactions are no longer buried inside the broader effects overview."
  else if route_name == "effects-workflow" then "Workflow effects are isolated here so staged waits, mocked IO, and ambient operator state can be read without the other cases competing for attention."
  else if route_name == "effects-state" then "This route focuses on keyed local state, separate from domain data and remote workflow state."
  else if route_name == "effects-timer" then "Timer behavior stays deterministic because tests intercept `wait_ms` instead of waiting on wall-clock time."
  else "This route now shows the smaller effect cases that explain the core mechanics before the richer workflow and dialog demos branch off into their own subroutes."

pub fun effects_panel(item : model, results : list<test_result>, key : string = "panel") : app_view vnode
  feature_root("effects", key) {
    val cases = route_effect_cases(item, results)
    panel([
      div(cases, class = "case-grid"),
    ], title = "Effects", note = effects_panel_note(item.route_name), key = feature_key(), class_name = "effects-panel")
  }
