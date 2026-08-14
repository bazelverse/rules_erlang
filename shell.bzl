load("//private:is_windows.bzl", "IS_WINDOWS")
load(
    "//private:shell.bzl",
    _shell = "shell",
)

def shell(**kwargs):
    _shell(
        is_windows = IS_WINDOWS,
        **kwargs
    )
