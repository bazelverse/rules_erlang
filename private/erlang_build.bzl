load(
    "@bazel_skylib//rules:common_settings.bzl",
    "BuildSettingInfo",
)
load(
    "@bazel_tools//tools/build_defs/hash:hash.bzl",
    "sha256",
    "tools",
)
load(
    "//:util.bzl",
    "BEGINS_WITH_FUN",
    "QUERY_ERL_VERSION",
    "path_join",
)

OtpInfo = provider(
    doc = "A staged Erlang/OTP installation",
    fields = {
        "version": """The version that this build contains.
May be a prefix of the exact version found in the version_file.""",
        "release_dir": """Directory artifact holding the OTP installation,
None when OTP comes from the host.""",
        "erlang_home": """`<release_dir>/lib/erlang`, relative to the execroot;
absolute for a host installation. Read it through `erlang_dirs()`.""",
        "version_file": """A file containing the version of this
erlang, used to correctly invalidate the cache when an
external erlang is used""",
    },
)

# configure --prefix. Not where OTP ends up: the tree is staged into a declared directory and
# run from there. Every launcher resolves its own root via `dyn_erl --realpath` and prefers it
# over this recorded value, so the tree runs wherever Bazel puts it.
#
# Chosen to not exist, so anything that regresses to relying on the recorded path fails loudly
# instead of reading some other OTP on the machine.
NOMINAL_INSTALL_PREFIX = "/nonexistent/rules_erlang/otp"

def _erlang_build_impl(ctx):
    (_, _, filename) = ctx.attr.url.rpartition("/")
    downloaded_archive = ctx.actions.declare_file(filename)

    build_dir_tar = ctx.actions.declare_file(ctx.label.name + "_build.tar")
    build_log = ctx.actions.declare_file(ctx.label.name + "_build.log")
    release_dir_tar = ctx.actions.declare_file(ctx.label.name + "_release.tar")

    version_file = ctx.actions.declare_file(ctx.label.name + "_version")

    extra_configure_opts = " ".join(ctx.attr.extra_configure_opts)
    pre_configure_cmds = "\n".join(ctx.attr.pre_configure_cmds)
    post_configure_cmds = "\n".join(ctx.attr.post_configure_cmds)
    extra_make_opts = " ".join(ctx.attr.extra_make_opts)

    release_dir = ctx.actions.declare_directory(ctx.label.name + "_release")
    install_path = NOMINAL_INSTALL_PREFIX

    # At one point this rule recevied the erlang sources as a
    # label_list attribute, which had been fetched with a repository
    # rule. This had the unfortunate side effect of stripping out
    # empty directories which are expected to be present by the
    # otp makefiles. Instead this rule fetches the sources directly,
    # which also avoids unnecessarily fetching sources when they are
    # unused (such as when "external" erlang is used).
    ctx.actions.run_shell(
        inputs = [],
        outputs = [downloaded_archive],
        command = """set -euo pipefail

curl -L "{archive_url}" -o {archive_path}
""".format(
            archive_url = ctx.attr.url,
            archive_path = downloaded_archive.path,
        ),
        mnemonic = "OTP",
        progress_message = "Downloading {}".format(ctx.attr.url),
    )

    sha256file = sha256(ctx, downloaded_archive)

    # zipper = ctx.executable._zipper

    # GNU tar's --transform is not available in the bsdtar that macOS ships, so express the
    # same thing with --strip-components, which both implementations support. Every archive
    # this rule handles wraps its contents in a single top-level directory (otp_src_28.1 for
    # OTP 28.1), so stripping one component is equivalent to removing that prefix.
    strip_components = "--strip-components=1" if ctx.attr.strip_prefix != "" else ""

    ctx.actions.run_shell(
        inputs = [downloaded_archive, sha256file],
        outputs = [
            build_dir_tar,
            build_log,
            release_dir_tar,
        ],
        command = """set -euo pipefail

if [ -n "{sha256}" ]; then
    if [ "{sha256}" != "$(cat "{sha256file}")" ]; then
        echo "ERROR: Checksum mismatch. $(basename "{archive_path}") $(cat "{sha256file}") != {sha256}"
        exit 1
    fi
fi

ABS_BUILD_DIR_TAR=$PWD/{build_path}
ABS_RELEASE_DIR_TAR=$PWD/{release_path}
ABS_LOG=$PWD/{build_log}

ABS_BUILD_DIR="$(mktemp -d)"
ABS_DEST_DIR="$(mktemp -d)"

tar --extract \\
    {strip_components} \\
    --file "{archive_path}" \\
    --directory "$ABS_BUILD_DIR"

echo "Building OTP $(cat $ABS_BUILD_DIR/OTP_VERSION) in $ABS_BUILD_DIR"

trap 'catch $?' EXIT
catch() {{
    [[ $1 == 0 ]] || tail -n 50 "$ABS_LOG"
    echo "    archiving build dir to: {build_path}"
    cd "$ABS_BUILD_DIR"
    tar --create \\
        --file "$ABS_BUILD_DIR_TAR" \\
        *
    echo "    build log: {build_log}"
}}

cd "$ABS_BUILD_DIR"
{pre_configure_cmds}
./configure --prefix={install_path} {extra_configure_opts} >> "$ABS_LOG" 2>&1
{post_configure_cmds}
echo "    configure finished"
${{MAKE:=make}} {extra_make_opts} >> "$ABS_LOG" 2>&1
echo "    make finished"
${{MAKE}} install DESTDIR="$ABS_DEST_DIR" >> "$ABS_LOG" 2>&1
echo "    make install finished"

cd "$ABS_DEST_DIR"/{install_path}
tar --create \\
    --file "$ABS_RELEASE_DIR_TAR" \\
    *
""".format(
            sha256 = ctx.attr.sha256v,
            sha256file = sha256file.path,
            archive_path = downloaded_archive.path,
            strip_components = strip_components,
            build_path = build_dir_tar.path,
            release_path = release_dir_tar.path,
            install_path = install_path,
            build_log = build_log.path,
            extra_configure_opts = extra_configure_opts,
            pre_configure_cmds = pre_configure_cmds,
            post_configure_cmds = post_configure_cmds,
            extra_make_opts = extra_make_opts,
        ),
        use_default_shell_env = True,
        mnemonic = "OTP",
        progress_message = "Compiling otp from source",
    )

    erlang_home = path_join(release_dir.path, "lib", "erlang")

    # Ask the runtime its own version rather than trusting the version attribute.
    ctx.actions.run_shell(
        inputs = [release_dir_tar],
        outputs = [release_dir, version_file],
        command = """set -euo pipefail

tar --extract \\
    --directory {release_dir} \\
    --file {erlang_release_tar}

{begins_with_fun}
V=$("{erlang_home}"/bin/{query_erlang_version})
if ! beginswith "{erlang_version}" "$V"; then
echo "Erlang version mismatch (Expected {erlang_version}, found $V)"
exit 1
fi

echo "$V" >> {version_file}
""".format(
            release_dir = release_dir.path,
            begins_with_fun = BEGINS_WITH_FUN,
            query_erlang_version = QUERY_ERL_VERSION,
            erlang_version = ctx.attr.version,
            erlang_home = erlang_home,
            erlang_release_tar = release_dir_tar.path,
            version_file = version_file.path,
        ),
        mnemonic = "OTP",
        progress_message = "Staging otp {}".format(ctx.attr.version),
    )

    return [
        DefaultInfo(
            files = depset([
                release_dir,
                version_file,
            ]),
        ),
        OtpInfo(
            version = ctx.attr.version,
            release_dir = release_dir,
            erlang_home = erlang_home,
            version_file = version_file,
        ),
    ]

erlang_build = rule(
    implementation = _erlang_build_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "url": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "sha256v": attr.string(),
        "pre_configure_cmds": attr.string_list(),
        "extra_configure_opts": attr.string_list(),
        "post_configure_cmds": attr.string_list(),
        "extra_make_opts": attr.string_list(),
        "sha256": tools["sha256"],
    },
)

def _erlang_prebuilt_impl(ctx):
    """Stage an OTP binary release. Same output contract as erlang_build.

    The archive ships an `Install` script that must be run to populate bin/. It records the
    root it is given; that path is right on the producing machine and stale on one that pulls
    the artifact from cache, where dyn_erl takes over -- see NOMINAL_INSTALL_PREFIX.
    """
    (_, _, filename) = ctx.attr.url.rpartition("/")
    downloaded_archive = ctx.actions.declare_file(filename)
    release_dir = ctx.actions.declare_directory(ctx.label.name + "_release")
    version_file = ctx.actions.declare_file(ctx.label.name + "_version")

    erlang_home = path_join(release_dir.path, "lib", "erlang")

    ctx.actions.run_shell(
        inputs = [],
        outputs = [downloaded_archive],
        command = """set -euo pipefail

curl -L "{archive_url}" -o {archive_path}
""".format(
            archive_url = ctx.attr.url,
            archive_path = downloaded_archive.path,
        ),
        mnemonic = "OTP",
        progress_message = "Downloading {}".format(ctx.attr.url),
    )

    sha256file = sha256(ctx, downloaded_archive)

    # Same reasoning as erlang_build: --strip-components rather than --transform, because
    # macOS ships bsdtar. A binary release wraps everything in one top-level directory.
    strip_components = "--strip-components=1" if ctx.attr.strip_prefix != "" else ""

    ctx.actions.run_shell(
        inputs = [downloaded_archive, sha256file],
        outputs = [release_dir, version_file],
        command = """set -euo pipefail

if [ -n "{sha256}" ]; then
    if [ "{sha256}" != "$(cat "{sha256file}")" ]; then
        echo "ERROR: Checksum mismatch. $(basename "{archive_path}") $(cat "{sha256file}") != {sha256}"
        exit 1
    fi
fi

# Install records the root it is given, so it has to be told an absolute one.
ABS_ERLANG_HOME="$PWD/{erlang_home}"

mkdir -p "$ABS_ERLANG_HOME"
tar --extract \\
    {strip_components} \\
    --file "{archive_path}" \\
    --directory "$ABS_ERLANG_HOME"

if [ ! -x "$ABS_ERLANG_HOME/Install" ]; then
    echo "ERROR: $ABS_ERLANG_HOME has no executable Install script."
    echo "       erlang_prebuilt expects an OTP binary release (the layout published at"
    echo "       builds.hex.pm), not an otp_src source tarball -- use erlang_build for source."
    exit 1
fi

(cd "$ABS_ERLANG_HOME" && ./Install -minimal "$ABS_ERLANG_HOME")

{begins_with_fun}
V=$("$ABS_ERLANG_HOME"/bin/{query_erlang_version})
if ! beginswith "{erlang_version}" "$V"; then
echo "Erlang version mismatch (Expected {erlang_version}, found $V)"
exit 1
fi

echo "$V" >> {version_file}
""".format(
            sha256 = ctx.attr.sha256v,
            sha256file = sha256file.path,
            archive_path = downloaded_archive.path,
            strip_components = strip_components,
            erlang_home = erlang_home,
            begins_with_fun = BEGINS_WITH_FUN,
            query_erlang_version = QUERY_ERL_VERSION,
            erlang_version = ctx.attr.version,
            version_file = version_file.path,
        ),
        use_default_shell_env = True,
        mnemonic = "OTP",
        progress_message = "Staging prebuilt otp {}".format(ctx.attr.version),
    )

    return [
        DefaultInfo(
            files = depset([
                release_dir,
                version_file,
            ]),
        ),
        OtpInfo(
            version = ctx.attr.version,
            release_dir = release_dir,
            erlang_home = erlang_home,
            version_file = version_file,
        ),
    ]

erlang_prebuilt = rule(
    implementation = _erlang_prebuilt_impl,
    attrs = {
        "version": attr.string(mandatory = True),
        "url": attr.string(mandatory = True),
        "strip_prefix": attr.string(),
        "sha256v": attr.string(),
        "sha256": tools["sha256"],
    },
)

def _erlang_external_impl(ctx):
    erlang_home = ctx.attr.erlang_home
    if erlang_home == "":
        erlang_home = ctx.attr._erlang_home[BuildSettingInfo].value

    erlang_version = ctx.attr.erlang_version
    if erlang_version == "":
        erlang_version = ctx.attr._erlang_version[BuildSettingInfo].value

    version_file = ctx.actions.declare_file(ctx.label.name + "_version")

    ctx.actions.run_shell(
        inputs = [],
        outputs = [version_file],
        command = """set -euo pipefail

{begins_with_fun}
V=$("{erlang_home}"/bin/{query_erlang_version})
if ! beginswith "{erlang_version}" "$V"; then
echo "Erlang version mismatch (Expected {erlang_version}, found $V)"
exit 1
fi

echo "$V" >> {version_file}
""".format(
            begins_with_fun = BEGINS_WITH_FUN,
            query_erlang_version = QUERY_ERL_VERSION,
            erlang_version = erlang_version,
            erlang_home = erlang_home,
            version_file = version_file.path,
        ),
        mnemonic = "OTP",
        progress_message = "Validating otp at {}".format(erlang_home),
    )

    return [
        DefaultInfo(
            files = depset([version_file]),
        ),
        OtpInfo(
            version = erlang_version,
            release_dir = None,
            erlang_home = erlang_home,
            version_file = version_file,
        ),
    ]

erlang_external = rule(
    implementation = _erlang_external_impl,
    attrs = {
        "_erlang_home": attr.label(default = Label("//:erlang_home")),
        "_erlang_version": attr.label(default = Label("//:erlang_version")),
        "erlang_home": attr.string(),
        "erlang_version": attr.string(),
    },
)
