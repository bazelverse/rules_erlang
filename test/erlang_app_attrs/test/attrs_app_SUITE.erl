-module(attrs_app_SUITE).

-export([all/0, hello/1]).

all() ->
    [hello].

hello(_Config) ->
    world = attrs_app:hello().
