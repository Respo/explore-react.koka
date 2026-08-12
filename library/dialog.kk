module library/dialog

import explore/react/core

pub type dialog_kind
  Dialog_none
  Dialog_alert
  Dialog_prompt
  Dialog_dialog
  Dialog_drawer

pub fun show_kind(k : dialog_kind) : string
  match k
    Dialog_none -> "none"
    Dialog_alert -> "alert"
    Dialog_prompt -> "prompt"
    Dialog_dialog -> "dialog"
    Dialog_drawer -> "drawer"

pub struct dialog_demo
  kind : dialog_kind
  title : string
  message : string
  prompt_value : string
  prompt_error : string
  result_note : string
  activity_log : list<string>

pub struct dialog_update
  dialog : dialog_demo
  notice : string
  audit_message : maybe<string>

pub type dialog_footer
  Footer_submit(label : string)
  Footer_primary_only(label : string)
  Footer_primary_with_cancel(label : string)

pub struct dialog_overlay_spec
  shell_class : string
  card_key : string
  card_class : string
  body_children : list<vnode>
  footer : dialog_footer

pub struct dialog_overlay_controls
  close_listener : listener
  primary_listener : listener
  submit_listener : listener

pub fun initial_dialog_demo(result_note : string) : dialog_demo
  Dialog_demo(Dialog_none, "", "", "", "", result_note, Nil)

pub fun dialog_is_open(item : dialog_demo) : <div> bool
  match item.kind
    Dialog_none -> False
    _ -> True

pub fun dialog_open_payload(kind : string) : string
  "dialog-open-" ++ kind

fun append_dialog_attrs(left : list<attr>, right : list<attr>) : <div> list<attr>
  match left
    Nil -> right
    Cons(head, rest) -> Cons(head, append_dialog_attrs(rest, right))

fun dialog_dismiss_attr() : attr
  text_attr("data-k-dialog-dismiss", "true")

fun dialog_shell_attrs(current : dialog_demo, close_listener : listener) : list<attr>
  [
    text_attr("data-k-dialog-shell", "true"),
    text_attr("data-k-dialog-surface", match current.kind { Dialog_drawer -> "drawer"; _ -> "modal" }),
    text_attr("data-k-dialog-close", listener/payload(close_listener)),
  ]

pub fun dialog_primary_focus_marker() : string
  "dialog-primary-focus"

pub fun dialog_prompt_focus_marker() : string
  "dialog-prompt-focus"

pub fun dialog_focus_marker(current : dialog_demo) : string
  match current.kind
    Dialog_prompt -> dialog_prompt_focus_marker()
    _ -> dialog_primary_focus_marker()

fun append_dialog_log(lines : list<string>, value : string) : <div> list<string>
  lines ++ [value]

pub fun open_dialog(current : dialog_demo, kind : dialog_kind, title : string, message : string, prompt_value : string, notice : string) : <div> dialog_update
  Dialog_update(
    current(
      kind = kind,
      title = title,
      message = message,
      prompt_value = prompt_value,
      prompt_error = "",
      activity_log = append_dialog_log(current.activity_log, "[open] " ++ title)),
    notice,
    Nothing)

pub fun close_dialog(current : dialog_demo, result_note : string, notice : string, log_line : string) : <div> dialog_update
  Dialog_update(
    current(
      kind = Dialog_none,
      title = "",
      message = "",
      prompt_value = "",
      prompt_error = "",
      result_note = result_note,
      activity_log = append_dialog_log(current.activity_log, log_line)),
    notice,
    Nothing)

pub fun update_dialog_prompt(current : dialog_demo, value : string) : dialog_demo
  current(prompt_value = value, prompt_error = "")

fun validate_prompt(value : string) : <div> maybe<string>
  val trimmed = trim(value)
  val size = chars/count(trimmed)
  if size < 3 then Just("Use 3-8 characters.")
  else if size > 8 then Just("Keep the prompt within 8 characters.")
  else Nothing

pub fun submit_dialog_prompt(current : dialog_demo, success_notice : string) : <div> dialog_update
  val trimmed = trim(current.prompt_value)
  match validate_prompt(trimmed)
    Just(message) -> Dialog_update(current(prompt_error = message), message, Nothing)
    Nothing -> Dialog_update(
      close_dialog(current, "Prompt submitted: " ++ trimmed, success_notice, "[submit] prompt => " ++ trimmed).dialog,
      success_notice,
      Just("Prompt submitted: " ++ trimmed))

pub fun resolve_dialog_primary(current : dialog_demo, result_note : string, notice : string, log_line : string, audit_message : string) : <div> dialog_update
  Dialog_update(close_dialog(current, result_note, notice, log_line).dialog, notice, Just(audit_message))

fun dismiss_button(key : string, class_name : string, marker : maybe<string>, action_listener : listener, label : string) : vnode
  val attr_list = match marker
    Just(found) -> [class_attr(class_name), text_attr("data-k-effect", found), dialog_dismiss_attr()]
    Nothing -> [class_attr(class_name), dialog_dismiss_attr()]
  button_key(key, raw_attrs(attr_list), on(click = action_listener), label)

fun dialog_header(current : dialog_demo, close_listener : listener) : <div> vnode
  div(props(class = "dialog-header"), [
    div(props(class = "stack"), [
      strong(props(class = "section-title"), current.title),
      p(props(class = "case-detail"), current.message),
    ]),
    dismiss_button("dialog-close-top", "button", Nothing, close_listener, "Close"),
  ])

fun dialog_actions(footer : dialog_footer, controls : dialog_overlay_controls) : <div> vnode
  match footer
    Footer_submit(submit_label) ->
      div(props(class = "button-row dialog-actions"), [
        dismiss_button("dialog-cancel", "button", Nothing, controls.close_listener, "Cancel"),
        button(props(class = "button button-primary"), on(click = controls.submit_listener), submit_label),
      ])
    Footer_primary_only(primary_label) ->
      div(props(class = "button-row dialog-actions"), [
        dismiss_button("dialog-primary", "button button-primary dialog-primary-button", Just(dialog_primary_focus_marker()), controls.primary_listener, primary_label),
      ])
    Footer_primary_with_cancel(primary_label) ->
      div(props(class = "button-row dialog-actions"), [
        dismiss_button("dialog-cancel", "button", Nothing, controls.close_listener, "Cancel"),
        dismiss_button("dialog-primary", "button button-primary dialog-primary-button", Just(dialog_primary_focus_marker()), controls.primary_listener, primary_label),
      ])

fun dismiss_backdrop(close_listener : listener) : <div> vnode
  el("div", "dialog-backdrop", append_dialog_attrs([class_attr("dialog-backdrop")], [dialog_dismiss_attr()]), [close_listener], "", Nil)

fun overlay_card(current : dialog_demo, spec : dialog_overlay_spec, controls : dialog_overlay_controls) : <div> vnode
  article_key(spec.card_key, props(class = spec.card_class), [
    dialog_header(current, controls.close_listener),
    div(props(class = "dialog-panel-body"), spec.body_children),
    dialog_actions(spec.footer, controls),
  ])

pub fun render_dialog_overlay(current : dialog_demo, spec : dialog_overlay_spec, controls : dialog_overlay_controls) : <div> vnode
  section_key(spec.card_key ++ "-shell", raw_attrs(append_dialog_attrs([class_attr(spec.shell_class)], dialog_shell_attrs(current, controls.close_listener))), [
    dismiss_backdrop(controls.close_listener),
    overlay_card(current, spec, controls),
  ])