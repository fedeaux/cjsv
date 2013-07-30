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

wrap : (map, template) ->
  # JSV.wrap(JSV.list(), JSV.list_wrapper())
  # JSV.wrap({list : JSV.list()
    #          header : JSV.header()}, JSV.list_wrapper())
  if typeof map == 'string'
    map = {__placeholder__: map}

  html = template
  for placeholder, content of map
    html = html.replace placeholder, content
  html

empty : () ->
  return ''