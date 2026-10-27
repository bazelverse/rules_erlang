load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//private:erlang_build.bzl", "OtpInfo")

def _fake_tree_otp_impl(ctx):
    return [OtpInfo(
        version = "0.0",
        release_dir_tar = None,
        install_path = None,
        # Rules must not use this when tree is set.
        erlang_home = "/fake_tree_otp/erlang_home/not/used",
        version_file = ctx.file.version_file,
        tree = depset(ctx.files.srcs),
    )]

fake_tree_otp = rule(
    implementation = _fake_tree_otp_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True, mandatory = True),
        "version_file": attr.label(allow_single_file = True, mandatory = True),
    },
    provides = [OtpInfo],
)

def _fake_release_otp_impl(ctx):
    return [OtpInfo(
        version = "0.0",
        release_dir_tar = ctx.file.release_dir_tar,
        install_path = "/tmp/bazel/erlang/fake",
        erlang_home = "/tmp/bazel/erlang/fake",
        version_file = ctx.file.version_file,
    )]

fake_release_otp = rule(
    implementation = _fake_release_otp_impl,
    attrs = {
        "release_dir_tar": attr.label(allow_single_file = True, mandatory = True),
        "version_file": attr.label(allow_single_file = True, mandatory = True),
    },
    provides = [OtpInfo],
)

def _extra_toolchains_transition_impl(_settings, attr):
    return {"//command_line_option:extra_toolchains": [str(attr.toolchain)]}

_extra_toolchains_transition = transition(
    implementation = _extra_toolchains_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:extra_toolchains"],
)

def _with_fake_tree_toolchain_impl(ctx):
    return [DefaultInfo(files = depset(ctx.files.target))]

with_fake_tree_toolchain = rule(
    implementation = _with_fake_tree_toolchain_impl,
    attrs = {
        "target": attr.label(cfg = _extra_toolchains_transition),
        "toolchain": attr.label(),
    },
)

_TREE = str(Label("//private/otp_tree_test:fake_tree_toolchain"))
_RELEASE = str(Label("//private/otp_tree_test:fake_release_toolchain"))
_TREE_FILES = [
    "fake_otp/OTP_VERSION",
    "fake_otp/bin/erl",
    "fake_otp/bin/erlc",
    "fake_otp/bin/escript",
]
_PKG = "private/otp_tree_test/"
_HOME = 'RULES_ERLANG_HOME="$(cd "$(dirname "{}fake_otp/OTP_VERSION")" && pwd)"'.format(_PKG)

def _assert_has_tree(env, paths, what):
    for f in _TREE_FILES:
        asserts.true(env, _PKG + f in paths, "{} misses {}".format(what, f))

def _action_with_tree_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.argv]
    asserts.equals(env, 1, len(actions), "expected one shell action")
    if actions:
        action = actions[0]
        command = " ".join(action.argv)
        asserts.true(env, _HOME in command, "home is not derived:\n" + command)
        asserts.true(env, '"${RULES_ERLANG_HOME}"/bin/erl' in command, "erl not run from the derived home:\n" + command)
        asserts.false(env, "tar --extract" in command, "tree toolchain unpacks a tar:\n" + command)
        asserts.false(env, "/fake_tree_otp/erlang_home" in command, "erlang_home used:\n" + command)
        _assert_has_tree(env, [f.short_path for f in action.inputs.to_list()], "action inputs")
    return analysistest.end(env)

action_with_tree_test = analysistest.make(
    _action_with_tree_test_impl,
    config_settings = {"//command_line_option:extra_toolchains": [_TREE]},
)

def _test_script_with_tree_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)
    writes = [a for a in analysistest.target_actions(env) if a.mnemonic == "FileWrite"]
    asserts.equals(env, 1, len(writes), "expected one FileWrite action")
    if writes:
        script = writes[0].content
        asserts.true(env, _HOME in script, "home is not derived from the short path:\n" + script)
        asserts.false(env, "/fake_tree_otp/erlang_home" in script, "erlang_home used:\n" + script)
    _assert_has_tree(
        env,
        [f.short_path for f in target[DefaultInfo].default_runfiles.files.to_list()],
        "runfiles",
    )
    return analysistest.end(env)

test_script_with_tree_test = analysistest.make(
    _test_script_with_tree_test_impl,
    config_settings = {"//command_line_option:extra_toolchains": [_TREE]},
)

def _action_with_release_tar_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.argv]
    asserts.equals(env, 1, len(actions), "expected one shell action")
    if actions:
        command = " ".join(actions[0].argv)
        asserts.true(env, "tar --extract" in command, "release tar not unpacked:\n" + command)
        asserts.false(env, "RULES_ERLANG_HOME" in command, "tree home used without a tree:\n" + command)
    return analysistest.end(env)

action_with_release_tar_test = analysistest.make(
    _action_with_release_tar_test_impl,
    config_settings = {"//command_line_option:extra_toolchains": [_RELEASE]},
)

def _template_vars_test_impl(ctx):
    env = analysistest.begin(ctx)
    variables = analysistest.target_under_test(env)[platform_common.TemplateVariableInfo].variables
    asserts.true(
        env,
        variables["ERLANG_HOME"].endswith(_PKG + "fake_otp"),
        "ERLANG_HOME make variable is " + variables["ERLANG_HOME"],
    )
    return analysistest.end(env)

template_vars_test = analysistest.make(_template_vars_test_impl)

def otp_tree_test_suite(name):
    action_with_tree_test(
        name = "erl_eval_with_tree_test",
        target_under_test = ":where",
    )
    test_script_with_tree_test(
        name = "eunit_with_tree_test",
        target_under_test = ":fake_eunit",
    )
    action_with_release_tar_test(
        name = "erl_eval_with_release_tar_test",
        target_under_test = ":where",
    )
    template_vars_test(
        name = "template_vars_with_tree_test",
        target_under_test = ":fake_tree_erlang",
    )
    native.test_suite(
        name = name,
        tests = [
            ":erl_eval_with_tree_test",
            ":eunit_with_tree_test",
            ":erl_eval_with_release_tar_test",
            ":template_vars_with_tree_test",
        ],
    )
