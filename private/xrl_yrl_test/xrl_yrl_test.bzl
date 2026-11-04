load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//private:erlang_build.bzl", "OtpInfo")

def _fake_release_otp_impl(ctx):
    return [OtpInfo(
        version = "0",
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

def _installs_erlang_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "ERLC"]
    asserts.equals(env, 1, len(actions), "expected one ERLC action")
    if actions:
        action = actions[0]
        command = " ".join(action.argv)
        asserts.true(
            env,
            "tar --extract" in command,
            "ERLC command does not unpack the release tar:\n" + command,
        )
        asserts.true(
            env,
            "fake_release.tar" in command,
            "ERLC command does not name the release tar:\n" + command,
        )
        inputs = [f.basename for f in action.inputs.to_list()]
        asserts.true(env, "fake_release.tar" in inputs, "release tar is not an input")
    return analysistest.end(env)

installs_erlang_test = analysistest.make(
    _installs_erlang_test_impl,
    config_settings = {
        "//command_line_option:extra_toolchains": [
            str(Label("//private/xrl_yrl_test:fake_toolchain")),
        ],
    },
)

def xrl_yrl_test_suite(name):
    installs_erlang_test(
        name = "lexer_installs_erlang_test",
        target_under_test = ":lexer",
    )
    installs_erlang_test(
        name = "parser_installs_erlang_test",
        target_under_test = ":parser",
    )
    native.test_suite(
        name = name,
        tests = [
            ":lexer_installs_erlang_test",
            ":parser_installs_erlang_test",
        ],
    )
