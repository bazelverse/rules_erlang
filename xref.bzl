load("//private:is_windows.bzl", "IS_WINDOWS")
load("//private:xref.bzl", "xref_test")

XREF_TAG = "xref"

def xref(
        name = "xref",
        target = ":erlang_app",
        tags = [],
        **kwargs):
    xref_test(
        xrefr = Label("@rules_erlang//tools/xref_runner:xrefr"),
        name = name,
        target = target,
        is_windows = IS_WINDOWS,
        tags = tags + [XREF_TAG],
        **kwargs
    )
