module demo/shared

import explore/react

pub fun panel(children : list<vnode>, title : string, note : string, key : string, class_name : string) : vnode
  section([
    h2(title, class = "section-title"),
    p(note, key = key ++ "-note", class = "section-note", data_effect = key ++ "-note"),
    div(children, class = "stack"),
  ], key = key, class = "panel " ++ class_name)

pub fun summary_chip(label : string, value : string) : vnode
  div([
    span(label, class = "summary-label"),
    strong(value, class = "summary-value"),
  ], class = "summary-chip")
