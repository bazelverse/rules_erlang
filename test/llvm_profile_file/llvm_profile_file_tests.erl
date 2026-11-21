-module(llvm_profile_file_tests).

-include_lib("eunit/include/eunit.hrl").

%% On Linux %b (the build id) is added before %m, so that two shared
%% libraries with the same layout write separate profiles.
llvm_profile_file_test() ->
    ?assertEqual(expected(os:type()), os:getenv("LLVM_PROFILE_FILE")).

expected({unix, linux}) -> "prof/%h-%p-%b-%m.profraw";
expected(_) -> "prof/%h-%p-%m.profraw".
