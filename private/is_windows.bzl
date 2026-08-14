"""The Windows condition shared by every macro that forwards `is_windows`.

The key is a `Label`, not the bare string "@platforms//os:windows". A `select()`
key written as a string is resolved against the repo mapping of the package that
*instantiates* the macro, not the one that defines it. Because every one of these
selects lives in a macro a consumer calls from its own BUILD file, the string
form obliged every consumer to declare `bazel_dep(name = "platforms")` of their
own, and failed analysis with "No repository visible as '@platforms'" if they did
not. `Label` resolves against this module's repo mapping, where the dependency is
declared.

The question never arose while the key was
`@bazel_tools//src/conditions:host_windows`, because `bazel_tools` is an implicit
dependency of every module and is visible from everywhere. Migrating to the
`platforms` constraint introduced the requirement silently: a consumer that
happened to depend on `platforms` for its own reasons, as this repository's own
test module does, would never have noticed.

It lives here rather than being repeated because it was repeated: nine identical
selects across six files. That is the shape of a fix that lands in some of them
and not the others, which is exactly what happened to the `allow_empty` glob fix
in 3.18.0.
"""

IS_WINDOWS = select({
    Label("@platforms//os:windows"): True,
    "//conditions:default": False,
})
