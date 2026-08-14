load("//private:eunit.bzl", "eunit_test")
load("//private:is_windows.bzl", "IS_WINDOWS")

def eunit(
        name = "eunit",
        coverdata_to_lcov = Label("@rules_erlang//tools/coverdata_to_lcov:coverdata_to_lcov"),
        **kwargs):
    eunit_test(
        name = name,
        coverdata_to_lcov = coverdata_to_lcov,
        is_windows = IS_WINDOWS,
        **kwargs
    )
