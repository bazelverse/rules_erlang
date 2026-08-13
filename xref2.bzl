load("//private:is_windows.bzl", "IS_WINDOWS")
load(
    "//private:xref2.bzl",
    "xref_query",
    "xref_test",
)
load(
    ":xref.bzl",
    _XREF_TAG = "XREF_TAG",
)

XREF_TAG = _XREF_TAG

def xref(
        name = "xref",
        target = ":erlang_app",
        size = "small",
        tags = [],
        **kwargs):
    xref_test(
        name = name,
        target = target,
        is_windows = IS_WINDOWS,
        size = size,
        tags = tags + [XREF_TAG],
        **kwargs
    )
    xref_query(
        name = name + "-query",
        testonly = True,
        target = target,
        is_windows = IS_WINDOWS,
        tags = tags,
        **kwargs
    )
