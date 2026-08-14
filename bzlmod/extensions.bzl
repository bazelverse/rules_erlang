load(
    "//private:xref_runner_sources.bzl",
    "xref_runner_sources",
)
load(
    "//repositories:erlang_config.bzl",
    "INSTALLATION_TYPE_EXTERNAL",
    "INSTALLATION_TYPE_INTERNAL",
    "INSTALLATION_TYPE_PREBUILT",
    _erlang_config_rule = "erlang_config",
)
load(
    "//tools:erlang.bzl",
    "DEFAULT_ERLANG_SHA256",
    "DEFAULT_ERLANG_VERSION",
)
load(
    ":erlang_package.bzl",
    "git_package",
    "hex_package",
    "hex_tree",
    "log",
    "without_requirement",
)
load(
    ":hex_pm.bzl",
    "hex_package_info",
    "satisfies",
)
load(
    ":semver.bzl",
    "compatible",
    "lt",
    "version_from_string",
)

def _erlang_config(ctx):
    types = {}
    versions = {}
    urls = {}
    strip_prefixs = {}
    sha256s = {}
    erlang_homes = {}
    pre_configure_cmdss = {}
    extra_configure_optss = {}
    post_configure_cmdss = {}
    extra_make_optss = {}
    extra_exec_constraintss = {}
    owners_by_name = {}

    for mod in ctx.modules:
        for erlang in mod.tags.external_erlang_from_path:
            if erlang.name in types:
                fail("{} declares an erlang installation named {}, but the name is already used by {}".format(
                    mod.name,
                    erlang.name,
                    owners_by_name[erlang.name].name,
                ))
            types[erlang.name] = INSTALLATION_TYPE_EXTERNAL
            versions[erlang.name] = erlang.version
            erlang_homes[erlang.name] = erlang.erlang_home
            owners_by_name[erlang.name] = mod

        for erlang in mod.tags.internal_erlang_from_http_archive:
            if erlang.name in types:
                fail("{} declares an erlang installation named {}, but the name is already used by {}".format(
                    mod.name,
                    erlang.name,
                    owners_by_name[erlang.name].name,
                ))
            types[erlang.name] = INSTALLATION_TYPE_INTERNAL
            versions[erlang.name] = erlang.version
            urls[erlang.name] = erlang.url
            strip_prefixs[erlang.name] = erlang.strip_prefix
            sha256s[erlang.name] = erlang.sha256
            pre_configure_cmdss[erlang.name] = erlang.pre_configure_cmds
            extra_configure_optss[erlang.name] = erlang.extra_configure_opts
            post_configure_cmdss[erlang.name] = erlang.post_configure_cmds
            extra_make_optss[erlang.name] = erlang.extra_make_opts
            owners_by_name[erlang.name] = mod

        for erlang in mod.tags.internal_erlang_from_github_release:
            if erlang.name in types:
                fail("{} declares an erlang installation named {}, but the name is already used by {}".format(
                    mod.name,
                    erlang.name,
                    owners_by_name[erlang.name].name,
                ))
            url = "https://github.com/erlang/otp/releases/download/OTP-{v}/otp_src_{v}.tar.gz".format(
                v = erlang.version,
            )
            strip_prefix = "otp_src_{}".format(erlang.version)

            if erlang.version == DEFAULT_ERLANG_VERSION and erlang.sha256 == "":
                sha256 = DEFAULT_ERLANG_SHA256
            else:
                sha256 = erlang.sha256

            types[erlang.name] = INSTALLATION_TYPE_INTERNAL
            versions[erlang.name] = erlang.version
            urls[erlang.name] = url
            strip_prefixs[erlang.name] = strip_prefix
            sha256s[erlang.name] = sha256
            pre_configure_cmdss[erlang.name] = erlang.pre_configure_cmds
            extra_configure_optss[erlang.name] = erlang.extra_configure_opts
            post_configure_cmdss[erlang.name] = erlang.post_configure_cmds
            extra_make_optss[erlang.name] = erlang.extra_make_opts
            owners_by_name[erlang.name] = mod

        for erlang in mod.tags.prebuilt_erlang_from_http_archive:
            if erlang.name in types:
                fail("{} declares an erlang installation named {}, but the name is already used by {}".format(
                    mod.name,
                    erlang.name,
                    owners_by_name[erlang.name].name,
                ))
            types[erlang.name] = INSTALLATION_TYPE_PREBUILT
            versions[erlang.name] = erlang.version
            urls[erlang.name] = erlang.url
            strip_prefixs[erlang.name] = erlang.strip_prefix
            sha256s[erlang.name] = erlang.sha256
            extra_exec_constraintss[erlang.name] = erlang.exec_compatible_with
            owners_by_name[erlang.name] = mod

        for erlang in mod.tags.prebuilt_erlang_from_hex_builds:
            if erlang.name in types:
                fail("{} declares an erlang installation named {}, but the name is already used by {}".format(
                    mod.name,
                    erlang.name,
                    owners_by_name[erlang.name].name,
                ))

            # builds.hex.pm publishes an OTP binary release per (arch, os) with the sha256 of
            # each archive listed alongside it in builds.txt, so a consumer pins the checksum
            # upstream already publishes rather than mirroring the archive to compute one.
            url = "https://builds.hex.pm/builds/otp/{arch}/{os}/OTP-{v}.tar.gz".format(
                arch = erlang.arch,
                os = erlang.os,
                v = erlang.version,
            )

            types[erlang.name] = INSTALLATION_TYPE_PREBUILT
            versions[erlang.name] = erlang.version
            urls[erlang.name] = url
            strip_prefixs[erlang.name] = "OTP-{}".format(erlang.version)
            sha256s[erlang.name] = erlang.sha256
            extra_exec_constraintss[erlang.name] = erlang.exec_compatible_with
            owners_by_name[erlang.name] = mod

    _erlang_config_rule(
        name = "erlang_config",
        rules_erlang_workspace = "@rules_erlang",
        types = types,
        versions = versions,
        urls = urls,
        strip_prefixs = strip_prefixs,
        sha256s = sha256s,
        erlang_homes = erlang_homes,
        pre_configure_cmdss = pre_configure_cmdss,
        extra_configure_optss = extra_configure_optss,
        post_configure_cmdss = post_configure_cmdss,
        extra_make_optss = extra_make_optss,
        extra_exec_constraintss = extra_exec_constraintss,
    )

external_erlang_from_path = tag_class(attrs = {
    "name": attr.string(),
    "version": attr.string(),
    "erlang_home": attr.string(),
})

internal_erlang_from_http_archive = tag_class(attrs = {
    "name": attr.string(),
    "version": attr.string(),
    "url": attr.string(),
    "strip_prefix": attr.string(),
    "sha256": attr.string(),
    "pre_configure_cmds": attr.string_list(),
    "extra_configure_opts": attr.string_list(),
    "post_configure_cmds": attr.string_list(),
    "extra_make_opts": attr.string_list(),
})

internal_erlang_from_github_release = tag_class(attrs = {
    "name": attr.string(
        default = "internal",
    ),
    "version": attr.string(
        default = DEFAULT_ERLANG_VERSION,
    ),
    "sha256": attr.string(),
    "pre_configure_cmds": attr.string_list(),
    "extra_configure_opts": attr.string_list(),
    "post_configure_cmds": attr.string_list(),
    "extra_make_opts": attr.string_list(),
})

# Any OTP *binary release* -- an archive with an `Install` script at its root, as opposed to
# an otp_src source tarball. `exec_compatible_with` lets a repository register one prebuilt per
# execution architecture and let toolchain resolution choose between them.
prebuilt_erlang_from_http_archive = tag_class(attrs = {
    "name": attr.string(),
    "version": attr.string(),
    "url": attr.string(),
    "strip_prefix": attr.string(),
    "sha256": attr.string(),
    "exec_compatible_with": attr.string_list(),
})

# Convenience wrapper over builds.hex.pm, which publishes an OTP binary release per
# (arch, os) together with its sha256 in builds.txt -- so `sha256` here is a value copied
# from upstream rather than one computed by mirroring the archive.
prebuilt_erlang_from_hex_builds = tag_class(attrs = {
    "name": attr.string(),
    "version": attr.string(),
    "arch": attr.string(
        default = "amd64",
        doc = "Architecture segment as published by builds.hex.pm, e.g. amd64 or arm64.",
    ),
    "os": attr.string(
        default = "ubuntu-24.04",
        doc = "OS segment as published by builds.hex.pm. Must match the runtime's libc.",
    ),
    "sha256": attr.string(),
    "exec_compatible_with": attr.string_list(),
})

erlang_config = module_extension(
    implementation = _erlang_config,
    tag_classes = {
        "external_erlang_from_path": external_erlang_from_path,
        "internal_erlang_from_http_archive": internal_erlang_from_http_archive,
        "internal_erlang_from_github_release": internal_erlang_from_github_release,
        "prebuilt_erlang_from_http_archive": prebuilt_erlang_from_http_archive,
        "prebuilt_erlang_from_hex_builds": prebuilt_erlang_from_hex_builds,
    },
)

_RESOLVE_MAX_PASSES = 500

def _resolve_pass(ctx, packages):
    all_requirements = []
    for p in packages:
        # print("checking reqs for", p.name)
        all_requirements.extend(getattr(p, "requirements", []))
    if len(all_requirements) == 0:
        # no unmet requirements, end recursion
        return (True, packages)
    else:
        # at least one unmet requirement exists...
        name = all_requirements[0]["app"]
        requirements = []
        for r in all_requirements:
            if r["app"] == name:
                requirements.append(r["requirement"])
        requirers = []
        for p in packages:
            for r in getattr(p, "requirements", []):
                if r["app"] == name:
                    requirers.append(p.name)

        # check if it's already in our package list
        for p in packages:
            if p.name == name:
                if not all([satisfies(p.version, r) for r in requirements]):
                    log(ctx, "Ignoring conflicting requirements for {}, {} does not satisfy {} as required by {}".format(
                        name,
                        p.version,
                        requirements,
                        requirers,
                    ))
                return (False, [without_requirement(name, p) for p in packages])

        # check if a version exists on hex
        log(ctx, "Fetching package info for {} from hex.pm".format(name))
        package_info = hex_package_info(ctx, name)
        for release in package_info["releases"]:
            if all([satisfies(release["version"], r) for r in requirements]):
                log(ctx, "Using {}@{} required by {} satisfying {}".format(
                    name,
                    release["version"],
                    requirers,
                    requirements,
                ))
                hp = hex_package(ctx, name, release["version"], "", "")
                return (False, [without_requirement(name, p) for p in packages] + [hp])

        fail("Unable to find a version of {} satisfying".format(name), requirements)

def _resolve_hex_pm(ctx, packages):
    resolved = packages
    for i in range(0, _RESOLVE_MAX_PASSES):
        (done, resolved) = _resolve_pass(ctx, resolved)
        if done:
            return resolved
    fail("Dependencies were not resolved after {} passes.".format(_RESOLVE_MAX_PASSES))

def _newest(a, b):
    if a.version == b.version:
        if a.module.is_root:
            return a
        else:
            return b

    a_version = version_from_string(a.version)
    b_version = version_from_string(b.version)
    if a_version == None or b_version == None:
        fail("Version {dep_name}@{a_version} (required by {a_module}) & {dep_name}@{b_version} (required by {b_module}) cannot be resolved".format(
            dep_name = a.name,
            a_version = a.version,
            a_module = a.module.name,
            b_version = b.version,
            b_module = b.module.name,
        ))
    if not compatible(a_version, b_version):
        fail("Version {dep_name}@{a_version} (required by {a_module}) & {dep_name}@{b_version} (required by {b_module}) cannot be resolved (major version mismatch)".format(
            dep_name = a.name,
            a_version = a.version,
            a_module = a.module.name,
            b_version = b.version,
            b_module = b.module.name,
        ))
    if lt(a_version, b_version):
        return b
    else:
        return a

def _dedupe_by_version(packages):
    by_version = {}
    for p in packages:
        by_version[p.version] = p
    return by_version.values()

def _resolve_local(ctx, packages):
    deduped = []
    packages_by_name = {}
    for p in packages:
        if p.name in packages_by_name:
            packages_by_name[p.name].append(p)
        else:
            packages_by_name[p.name] = [p]
    for (name, dupes) in packages_by_name.items():
        p = dupes[0]
        for dupe in dupes[1:]:
            p = _newest(p, dupe)
        deduped.append(p)
        filtered_dupes = _dedupe_by_version(dupes)
        if len(filtered_dupes) > 1:
            log(ctx, "Multiple versions of {} requested ({}), selecting {}".format(
                name,
                ", ".join([p.version for p in filtered_dupes]),
                p.version,
            ))
    return deduped

def _erlang_package(ctx):
    xref_runner_sources()

    packages = []
    for mod in ctx.modules:
        for dep in mod.tags.hex_package_tree:
            packages.append(hex_tree(
                ctx,
                module = mod,
                name = dep.name,
                pkg = dep.pkg,
                version = dep.version,
            ))
        for dep in mod.tags.hex_package:
            if dep.build_file != None and dep.build_file_content != "":
                fail("build_file and build_file_content cannot be set simultaneously for", dep.name)
            if dep.testonly and (dep.build_file != None or dep.build_file_content != ""):
                fail("testonly has no effect when build_file or build_file_content is set:", dep.name)
            packages.append(hex_package(
                ctx,
                module = mod,
                name = dep.name,
                pkg = dep.pkg,
                version = dep.version,
                sha256 = dep.sha256,
                build_file = dep.build_file,
                build_file_content = dep.build_file_content,
                patches = dep.patches,
                patch_args = dep.patch_args,
                patch_cmds = dep.patch_cmds,
                testonly = dep.testonly,
            ))
        for dep in mod.tags.git_package:
            if dep.build_file != None and dep.build_file_content != "":
                fail("build_file and build_file_content cannot be set simultaneously for", dep.name)
            if dep.testonly and (dep.build_file != None or dep.build_file_content != ""):
                fail("testonly has no effect when build_file or build_file_content is set:", dep.remote, dep.repository)
            packages.append(git_package(
                ctx,
                module = mod,
                dep = dep,
            ))

    deduped = _resolve_local(ctx, packages)

    resolved = _resolve_hex_pm(ctx, deduped)

    if len(resolved) > 0:
        log(ctx, "Final package list:")
    for p in resolved:
        log(ctx, "    {}@{}".format(p.name, p.version))

    for p in resolved:
        p.f_fetch(p)

hex_package_tree_tag = tag_class(attrs = {
    "name": attr.string(mandatory = True),
    "pkg": attr.string(),
    "version": attr.string(mandatory = True),
})

hex_package_tag = tag_class(attrs = {
    "name": attr.string(mandatory = True),
    "pkg": attr.string(),
    "version": attr.string(mandatory = True),
    "sha256": attr.string(),
    "build_file": attr.label(),
    "build_file_content": attr.string(),
    "patches": attr.label_list(),
    "patch_args": attr.string_list(
        default = ["-p0"],
    ),
    "patch_cmds": attr.string_list(),
    "testonly": attr.bool(),
})

git_package_tag = tag_class(attrs = {
    "name": attr.string(),
    "remote": attr.string(),
    "repository": attr.string(),
    "branch": attr.string(),
    "tag": attr.string(),
    "commit": attr.string(),
    "build_file": attr.label(),
    "build_file_content": attr.string(),
    "patch_cmds": attr.string_list(),
    "testonly": attr.bool(),
})

erlang_package = module_extension(
    implementation = _erlang_package,
    tag_classes = {
        "hex_package": hex_package_tag,
        "hex_package_tree": hex_package_tree_tag,
        "git_package": git_package_tag,
    },
)
