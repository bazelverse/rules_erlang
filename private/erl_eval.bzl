load(
    "//tools:erlang_toolchain.bzl",
    "erlang_dirs",
    "erlang_preamble",
)

def _impl(ctx):
    outs = [
        ctx.actions.declare_file(f)
        for f in ctx.attr.outs
    ]

    (erlang_home, _, runfiles) = erlang_dirs(ctx)

    script = """set -euo pipefail

{erlang_preamble}

export SRCS="{srcs}"
export OUTS="{outs}"

"$ABS_ERLANG_HOME"/bin/erl \\
    -noshell \\
    -eval "$1"
""".format(
        erlang_preamble = erlang_preamble(ctx),
        erlang_home = erlang_home,
        srcs = ctx.configuration.host_path_separator.join([src.path for src in ctx.files.srcs]),
        outs = ctx.configuration.host_path_separator.join([out.path for out in outs]),
    )

    inputs = depset(
        direct = ctx.files.srcs,
        transitive = [runfiles.files],
    )

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = outs,
        command = script,
        arguments = [ctx.attr.expression],
    )

    return [
        DefaultInfo(files = depset(outs)),
    ]

erl_eval = rule(
    implementation = _impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "outs": attr.string_list(),
        "expression": attr.string(
            mandatory = True,
        ),
    },
    toolchains = ["//tools:toolchain_type"],
)
