-module(no_sname).

-export([node_name/0]).

node_name() ->
    node().
