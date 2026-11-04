load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _script(env):
    writes = [
        a
        for a in analysistest.target_actions(env)
        if a.mnemonic == "FileWrite"
    ]
    asserts.equals(env, 1, len(writes), "expected one FileWrite action")
    return writes[0].content if writes else ""

def _has_sname_test_impl(ctx):
    env = analysistest.begin(ctx)
    script = _script(env)
    asserts.true(env, "-hidden" in script, "-hidden missing:\n" + script)
    asserts.true(env, "-sname " in script, "-sname missing:\n" + script)
    return analysistest.end(env)

has_sname_test = analysistest.make(_has_sname_test_impl)

def _no_sname_test_impl(ctx):
    env = analysistest.begin(ctx)
    script = _script(env)
    asserts.false(env, "-hidden" in script, "-hidden present:\n" + script)
    asserts.false(env, "-sname" in script, "-sname present:\n" + script)
    asserts.true(env, "-logdir" in script, "-logdir missing:\n" + script)
    return analysistest.end(env)

no_sname_test = analysistest.make(_no_sname_test_impl)

def ct_auto_sname_test_suite(name):
    has_sname_test(
        name = "default_posix_test",
        target_under_test = ":default_posix",
    )
    has_sname_test(
        name = "auto_sname_posix_test",
        target_under_test = ":auto_sname_posix",
    )
    has_sname_test(
        name = "auto_sname_windows_test",
        target_under_test = ":auto_sname_windows",
    )
    no_sname_test(
        name = "no_sname_posix_test",
        target_under_test = ":no_sname_posix",
    )
    no_sname_test(
        name = "no_sname_windows_test",
        target_under_test = ":no_sname_windows",
    )
    native.test_suite(
        name = name,
        tests = [
            ":default_posix_test",
            ":auto_sname_posix_test",
            ":auto_sname_windows_test",
            ":no_sname_posix_test",
            ":no_sname_windows_test",
        ],
    )
