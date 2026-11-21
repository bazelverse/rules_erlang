-module(llvm_profile_file_SUITE).

-export([all/0, build_id_added/1]).

all() ->
    [build_id_added].

%% On Linux %b (the build id) is added before %m, so that two shared
%% libraries with the same layout write separate profiles.
build_id_added(_Config) ->
    Expected = expected(os:type()),
    Expected = os:getenv("LLVM_PROFILE_FILE").

expected({unix, linux}) -> "prof/%h-%p-%b-%m.profraw";
expected(_) -> "prof/%h-%p-%m.profraw".
