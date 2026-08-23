module demo/testspanel

import demo/tests/support
import demo/shared
import explore/react/core

fun test_item(item : test_result) : vnode
  val name = test_result/name(item)
  val detail = test_result/detail(item)
  val class_name = if test_result/passed(item) then "test-item test-pass" else "test-item test-fail"
  li([
    strong(name),
    p(detail, class = "case-detail"),
  ], key = name, class = class_name)

fun render_test_items(results : list<test_result>) : <div> list<vnode>
  map(results, test_item)

pub fun tests_panel(results : list<test_result>) : <div> vnode
  val passed = length(filter(results, fn(item) test_result/passed(item)))
  panel([
    ul(render_test_items(results), key = "test-results", class = "test-list"),
  ], title = "Checks", note = passed.show ++ " / " ++ length(results).show ++ " pass in-process.", key = "tests", class_name = "tests-panel")
