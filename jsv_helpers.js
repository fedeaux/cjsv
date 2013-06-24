make_args : function(a) {
    return escape(JSON.stringify(a));
},

parse_args : function(a) {
    return JSON.parse(unescape(a));
},

set_args : function(a) {
    JSV.args = a;
},

set_parse_args : function(a) {
    _a = JSV.parse_args(a);
    JSV.set_args(_a);
    return _a;
}