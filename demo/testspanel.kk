module demo/testspanel

import demo/tests/support
import demo/shared
import explore/react/core

fun test_item(item : test_result) : vnode
  val name = test_result/name(item)
  val detail = test_result/detail(item)
  val class_name = if test_result/passed(item) then "test-item test-pass" else "test-item test-fail"
  li_key(name, props(class = class_name), [
    strong(props, name),
    p(props(class = "case-detail"), detail),
  ])

fun render_test_items(results : list<test_result>) : <div> list<vnode>
  map(results, test_item)

pub fun tests_panel(results : list<test_result>) : <div> vnode
  val passed = length(filter(results, fn(item) test_result/passed(item)))
  panel("Checks", passed.show ++ " / " ++ length(results).show ++ " pass in-process.", "tests", "tests-panel", [
    ul_key("test-results", props(class = "test-list"), render_test_items(results)),
  ])
