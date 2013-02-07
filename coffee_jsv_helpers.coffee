make_args : (a) ->
  escape JSON.stringify a

parse_args : (a) ->
  JSON.parse unescape a

set_args : (a) ->
  JSV.args = a

set_parse_args : (a) ->
  _a = JSV.parse_args a
  JSV.set_args _a
  _a