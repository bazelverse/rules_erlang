-module(no_sname_SUITE).

-export([all/0, no_generated_name/1]).

all() ->
    [no_generated_name].

%% With auto_sname = False the node gets no -hidden and no generated
%% -sname, so -sname undefined from ct_run_extra_args leaves it unnamed.
no_generated_name(_Config) ->
    nonode@nohost = no_sname:node_name(),
    error = init:get_argument(hidden).
