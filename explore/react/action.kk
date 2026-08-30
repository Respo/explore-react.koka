module explore/react/action

pub struct action_codec<a>(schema : string, version : int, decode : (int, string) -> maybe<a>, encode : (a) -> string)

inline extern escape_action_field(text : string) : string
  js inline "encodeURIComponent(#1)"

inline extern unescape_action_field(text : string) : string
  js inline "((s) => { try { return decodeURIComponent(s); } catch (_) { return ''; } })(#1)"

inline extern valid_action_field(text : string) : bool
  js inline "((s) => { try { decodeURIComponent(s); return true; } catch (_) { return false; } })(#1)"

// Action codecs often need to carry more than one string while keeping the
// envelope JSON-free and deterministic. Fields are escaped independently so a
// feature codec can safely join them with a visible delimiter.
pub fun encode_action_field(text : string) : string
  escape_action_field(text)

pub fun decode_action_field(text : string) : maybe<string>
  if valid_action_field(text) then Just(unescape_action_field(text)) else Nothing

// One wire-friendly shape for both domain and component actions. `source`
// distinguishes ownership without coupling observation to reducer routing.
pub struct action_envelope(source : string, target : string, schema : string, version : int, payload : string)

pub effect action_observation
  fun observe_action(envelope : action_envelope) : ()

pub fun encode_action<a>(source : string, target : string, codec : action_codec<a>, action : a) : action_envelope
  Action_envelope(
    source = source,
    target = target,
    schema = codec.schema,
    version = codec.version,
    payload = codec.encode.(action))

pub fun decode_action<a>(codec : action_codec<a>, envelope : action_envelope) : maybe<a>
  if envelope.schema != codec.schema then Nothing
  else codec.decode.(envelope.version, envelope.payload)

pub fun emit_action<a>(source : string, target : string, codec : action_codec<a>, action : a) : <action_observation,div> ()
  observe_action(encode_action(source = source, target = target, codec = codec, action = action))

pub fun capture_actions<a,e>(action : () -> <action_observation|e> a) : e (a, list<action_envelope>)
  var actions := Nil
  with return(result) (result, reverse(actions))
  with fun observe_action(envelope) actions := Cons(envelope, actions)
  action()

pub fun discard_actions<a,e>(action : () -> <action_observation|e> a) : e a
  with fun observe_action(_envelope) ()
  action()
