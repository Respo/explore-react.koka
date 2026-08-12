module runtime/dom

extern import
  js file "inline/dom.js"

pub extern mount_html(root_id : string, html : string) : io ()
  js "_mount_html"

pub extern attach_events(root_id : string) : io ()
  js "_attach_events"

pub extern patch_html(root_id : string, path : string, html : string) : io ()
  js "_patch_html"

pub extern patch_attr(root_id : string, path : string, attr_name : string, attr_value : string) : io ()
  js "_patch_attr"

pub extern clear_attr(root_id : string, path : string, attr_name : string) : io ()
  js "_clear_attr"

pub extern sync_input(root_id : string, field_name : string, value : string) : io ()
  js "_sync_input"

pub extern browser_hash() : io string
  js "_browser_hash"

pub extern browser_set_hash(route_name : string) : io ()
  js "_browser_set_hash"

pub extern browser_focus(root_id : string, field_name : string) : io ()
  js "_browser_focus"

pub extern browser_flash_marker(root_id : string, marker_name : string, class_name : string) : io ()
  js "_browser_flash_marker"

pub extern browser_now_label() : string
  js "_browser_now_label"

pub extern browser_confirm(message : string) : bool
  js "_browser_confirm"

pub extern browser_log(message : string) : ()
  js "_browser_log"

pub extern browser_schedule_click(payload : string, delay : int) : ()
  js "_browser_schedule_click"

pub extern html_escape(text : string) : string
  js "_html_escape"

pub extern set_root_id(root_id : string) : io ()
  js "_set_root_id"

pub extern dom_focus(field_name : string) : io ()
  js "_dom_focus"

pub extern dom_flash(marker_name : string, class_name : string) : io ()
  js "_dom_flash"
