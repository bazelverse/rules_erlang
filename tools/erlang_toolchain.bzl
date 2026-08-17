load(
    "//:util.bzl",
    "windows_path",
)
load(
    "//private:erlang_build.bzl",
    "OtpInfo",
)

def _impl(ctx):
    otpinfo = ctx.attr.otp[OtpInfo]
    vars = {
        "OTP_VERSION": otpinfo.version,
        "ERLANG_HOME": otpinfo.erlang_home,
    }
    if otpinfo.release_dir != None:
        vars["ERLANG_RELEASE_DIR_PATH"] = otpinfo.release_dir.path
        vars["ERLANG_RELEASE_DIR_SHORT_PATH"] = otpinfo.release_dir.short_path
    return [
        platform_common.ToolchainInfo(otpinfo = otpinfo),
        platform_common.TemplateVariableInfo(vars),
    ]

erlang_toolchain = rule(
    implementation = _impl,
    attrs = {
        "otp": attr.label(
            mandatory = True,
            providers = [OtpInfo],
        ),
    },
    provides = [
        platform_common.ToolchainInfo,
        # Instead of using this toolchain for a genrule,
        # since toolchain resolution won't yet have applied,
        # use @rules_erlang//tools:erlang_vars as a
        # toolchain for genrule rules
        platform_common.TemplateVariableInfo,
    ],
)

def _build_info(ctx):
    return ctx.toolchains["//tools:toolchain_type"].otpinfo

def erlang_dirs(ctx, short_path = False):
    """Returns (erlang_home, release_dir, runfiles).

    erlang_home is relative -- to the execroot, or to the runfiles root under `short_path` --
    for a staged OTP, and absolute for a host one. `release_dir` is None for a host one.
    """
    info = _build_info(ctx)
    if info.release_dir != None:
        runfiles = ctx.runfiles([
            info.release_dir,
            info.version_file,
        ])
        erlang_home = info.erlang_home
        if short_path:
            # erlang_home is `<release_dir.path>/lib/erlang`; re-root it on the short path.
            erlang_home = info.release_dir.short_path + erlang_home[len(info.release_dir.path):]
    else:
        runfiles = ctx.runfiles([
            info.version_file,
        ])
        erlang_home = info.erlang_home
    return (erlang_home, info.release_dir, runfiles)

def erlang_preamble(ctx, short_path = False):
    """Shell defining $ABS_ERLANG_HOME. Emit before any use of the OTP tree.

    Absolute, so it survives a chdir. Handles both erlang_dirs() forms.
    """
    (erlang_home, _, _) = erlang_dirs(ctx, short_path = short_path)
    return """\
if [[ "{erlang_home}" == /* ]]; then
    ABS_ERLANG_HOME="{erlang_home}"
else
    ABS_ERLANG_HOME="$PWD/{erlang_home}"
fi\
""".format(erlang_home = erlang_home)

def version_file(ctx):
    info = _build_info(ctx)
    return info.version_file

def windows_erlang_home(ctx, short_path = False):
    """Absolute OTP root for a batch script, since a staged tree's path is relative."""
    (erlang_home, release_dir, _) = erlang_dirs(ctx, short_path = short_path)
    path = windows_path(erlang_home)
    return path if release_dir == None else "%CD%\\" + path
