module tests_main

import demo/tests
import demo/tests/support

fun result_line(item : test_result) : string
  (if test_result/passed(item) then "[pass] " else "[fail] ") ++ test_result/name(item) ++ " - " ++ test_result/detail(item)

fun print_results(results : list<test_result>) : console ()
  foreach(results, fn(item) println(result_line(item)))

fun main() : io ()
  print_results(append(demo_test_results(), [effect_runtime_test_result()]))
