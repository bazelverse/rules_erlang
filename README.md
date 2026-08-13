# rules_erlang

Bazel rules for building Erlang/OTP applications. Compile an app, run its EUnit
and Common Test suites, run xref and Dialyzer, and pull dependencies from Hex or git.

## Supported versions

CI covers the **latest two OTP releases**, currently **28** and **29**. Earlier
releases may well work, and nothing has been deliberately broken for them, but
they are untested here. Treat them as use-at-your-own-risk.

Requires bzlmod; WORKSPACE support was removed in 3.18.0. GitHub CI builds with
the Bazel pinned in `.bazelversion`, and the Bazel Central Registry presubmit
covers 7.x, 8.x and 9.x.

## Status

This repository continues the 3.x line of
[rabbitmq/rules_erlang](https://github.com/rabbitmq/rules_erlang), which is
archived. `3.16.0` was its last release; its `main` branch then stopped at an
unreleased `4.0.0-beta.1`, which never reached the registry and is not continued
here.

**For a bzlmod consumer, 3.18.0 is a drop-in replacement for 3.16.0.** No rule,
macro, provider or attribute changed; every commit between the two tags is one
documented fix. The one removal is the WORKSPACE entry point, which no supported
Bazel can load anyway. See [CHANGELOG.md](./CHANGELOG.md).

## Installation

> **Git pre-release only.** Pick one of the two override methods below. Once the
> Bazel Central Registry entry lands, delete the override and keep the
> `bazel_dep`; nothing else changes.

### Pinned to a release tag

```starlark
bazel_dep(name = "rules_erlang", version = "3.18.0")

archive_override(
    module_name = "rules_erlang",
    urls = ["https://github.com/bazelverse/rules_erlang/archive/refs/tags/3.18.0.tar.gz"],
    strip_prefix = "rules_erlang-3.18.0",
    integrity = "sha256-...",
)
```

To get the `integrity` value, run the build once with the attribute omitted.
Bazel fetches the archive and prints a warning containing the hash it computed;
paste that in. A *wrong* value fails the build and names the expected one, so
either route gets you there. Do not leave it out permanently: without it the
archive is re-fetched unverified.

### Pinned to a commit

```starlark
bazel_dep(name = "rules_erlang", version = "3.18.0")

git_override(
    module_name = "rules_erlang",
    remote = "https://github.com/bazelverse/rules_erlang.git",
    commit = "0000000000000000000000000000000000000000",
)
```

`commit` takes a full SHA. Use this to track work that has no tag yet. Prefer
the tag form for anything you ship: it is a fixed archive plus a checksum,
rather than a repository that has to stay reachable and re-clone.

The `version` in `bazel_dep` is still required either way. It is what the module
reports to the rest of the graph; the override decides what is actually fetched.

**Overrides only take effect in the root module.** If you depend on
`rules_erlang` indirectly, through
[rules_elixir](https://github.com/bazelverse/rules_elixir) for instance, the
override still has to be declared in *your* `MODULE.bazel`, and you need one for
every module in the graph that is not on the registry yet. An override written
by a dependency is ignored.

### Then, in the same `MODULE.bazel`

```starlark
erlang_config = use_extension(
    "@rules_erlang//bzlmod:extensions.bzl",
    "erlang_config",
)
use_repo(erlang_config, "erlang_config")

register_toolchains("@erlang_config//external:toolchain")
```

That uses the Erlang already on the machine. To have Bazel fetch and build a
pinned OTP instead:

```starlark
erlang_config.internal_erlang_from_github_release(
    name = "29",
    version = "29.0.5",
    sha256 = "...",
)
```

Set `RULES_ERLANG_SKIP_SYSTEM=1` to stop the extension probing the host for an
OTP install at all. That is what you want when every toolchain is hermetic:

```
build --repo_env=RULES_ERLANG_SKIP_SYSTEM=1
```

## Building an application

```starlark
load("@rules_erlang//:erlang_app.bzl", "erlang_app", "test_erlang_app")
load("@rules_erlang//:xref.bzl", "xref")
load("@rules_erlang//:dialyze.bzl", "dialyze", "plt")
load("@rules_erlang//:ct.bzl", "ct_suite", "assert_suites2")

APP_NAME = "my_cool_app"
APP_VERSION = "0.1.0"

erlang_app(
    app_name = APP_NAME,
    app_version = APP_VERSION,
)

test_erlang_app(
    app_name = APP_NAME,
    app_version = APP_VERSION,
)

xref()

dialyze()

ct_suite(
    name = "unit_SUITE",
)

assert_suites2()
```

```shell
bazel test //...                    # everything
bazel test //:unit_SUITE            # one suite

bazel test //:unit_SUITE \
    --test_env FOCUS="-group my_group -case my_case"    # one case
```

## Dependencies

### A few packages

The `erlang_package` extension declares them one at a time:

```starlark
erlang_package = use_extension(
    "@rules_erlang//bzlmod:extensions.bzl",
    "erlang_package",
)
erlang_package.hex_package(
    name = "thoas",
    version = "1.2.1",
    sha256 = "...",
)
use_repo(erlang_package, "thoas")
```

It also offers `hex_package_tree` and `git_package` tags.

### A whole closure

One `hex_package` call per package does not scale to an application closure. An
Ash or Phoenix app resolves to a few hundred packages, so `MODULE.bazel` grows a
couple of thousand lines of generated boilerplate; worse, every package has to be
named a second time in `use_repo` before anything can see it.

`hex_packages_extension` takes the closure as **data** instead, and exports a
single hub repository of aliases:

```starlark
# //third_party/hex:extensions.bzl
load(
    "@rules_erlang//bzlmod:hex_packages.bzl",
    "git_pkg",
    "hex_packages_extension",
    "hex_pkg",
)

hex = hex_packages_extension(
    packages = [
        hex_pkg(
            name = "ecto",
            version = "3.12.5",
            sha256 = "...",        # the OUTER tarball checksum, i.e. the last
            build_file = ...,      # field of the mix.lock entry
        ),
        # ... a few hundred more, generated
        git_pkg(
            name = "some_fork",
            remote = "https://github.com/org/some_fork.git",
            commit = "...",
            build_file = ...,
        ),
    ],
)
```

The root module then needs two lines, whatever the closure size:

```starlark
hex_ext = use_extension("//third_party/hex:extensions.bzl", "hex")
use_repo(hex_ext, "hexpm")
```

Packages are depended on as `@hexpm//:ecto`. Both `hub_name` and `repo_prefix`
are configurable; `hexpm` and `hex_` are the defaults.

Generate the package list from your `mix.lock` files and check it in beside the
generated `BUILD` stubs. `hex_archive` is unchanged and still available if you
would rather drive it yourself.

## Layout assumptions

The `erlang_app` and `ct_suite` macros expect the standard OTP layout, relative
to the Bazel package. For an application named `my_erlang_app`:

```
my_erlang_app
├── BUILD.bazel
├── include
│   └── my_header.hrl
├── priv
│   └── schema
├── src
│   └── my_erlang_app.erl
└── test
    └── unit_SUITE.erl
```

They also expect one convention, expressed through the `dest` attribute of
`erlang_bytecode`:

1. production bytecode goes in `ebin`
2. test bytecode goes in `src`
3. test suite and helper bytecode goes in `test`

A more arbitrary layout can be handled to some degree with the underlying
`erlang_bytecode`, `app_file`, `erlang_app_info` and `ct_test` rules that these
macros wrap.

## Further examples

- [rabbitmq/lz4-erlang](https://github.com/rabbitmq/lz4-erlang): bzlmod, plus
  native extensions
- [rabbitmq/rabbitmq-server](https://github.com/rabbitmq/rabbitmq-server): a
  large, complex consumer

## License

Dual licensed under the Apache License Version 2.0 and the Mozilla Public
License Version 2.0.

You may consider this library to be licensed under **any of the licenses in that
list**. For example, you may choose the Apache License 2.0 and include this
library in a commercial product.

See [LICENSE](./LICENSE) for details. Copyright, including the notice for the
original upstream work, is covered separately in [COPYRIGHT.md](./COPYRIGHT.md).
