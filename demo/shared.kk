module demo/shared

import explore/react/core

pub fun panel(title : string, note : string, key : string, class_name : string, children : list<vnode>) : vnode
  section_key(key, props(class = "panel " ++ class_name), [
    h2(props(class = "section-title"), title),
    p_key(key ++ "-note", props(class = "section-note", data_effect = key ++ "-note"), note),
    div(props(class = "stack"), children),
  ])

pub fun summary_chip(label : string, value : string) : vnode
  div(props(class = "summary-chip"), [
    span(props(class = "summary-label"), label),
    strong(props(class = "summary-value"), value),
  ])
