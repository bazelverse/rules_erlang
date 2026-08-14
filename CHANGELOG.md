# Changelog

## 3.20.0

Adds a third way to supply Erlang/OTP: an already-compiled binary release.

### Added

- **`prebuilt_erlang_from_http_archive` and `prebuilt_erlang_from_hex_builds`**
  (`bzlmod/extensions.bzl`, `repositories/erlang_config.bzl`,
  new `repositories/BUILD_prebuilt.tpl`, new `erlang_prebuilt` in
  `private/erlang_build.bzl`).

  Until now there were two ways to provide OTP, and neither covers a downloadable
  prebuilt:

  - `external_erlang_from_path` takes an absolute `erlang_home` that must already
    exist on whatever machine runs the action. That is a host dependency, which is
    exactly what a hermetic build is trying not to have, and it cannot be satisfied
    on a remote executor without baking OTP into the executor image.
  - `internal_erlang_from_http_archive` accepts any URL, but always feeds it to
    `erlang_build`, which runs `./configure && make`. Pointing it at a binary
    release does not skip the build; it fails, because there is nothing to
    configure.

  So a consumer who wanted a prebuilt OTP had to compile one anyway. The new tag
  classes fetch an OTP *binary release* and stage it, with no configure or make
  step.

  Measured on the same target, same machine, same forced re-execution
  (`--action_env=CACHEBUST=...` to defeat both caches), OTP 28.1 on linux/amd64:

  | | |
  |---|---|
  | `internal_erlang_from_github_release` | still compiling after 5 min, abandoned |
  | `prebuilt_erlang_from_hex_builds` | ~12s wall, staging action ~3-8s |

  The download is 71 MB for a 171 MB installed tree.

  `prebuilt_erlang_from_hex_builds` is a thin convenience over `builds.hex.pm`,
  which publishes a release per `(arch, os)` and lists each archive's sha256 in
  its `builds.txt`. The checksum a consumer pins is therefore one upstream already
  publishes, rather than one produced by mirroring the archive somewhere to compute
  it.

  ```python
  erlang_config_ext.prebuilt_erlang_from_hex_builds(
      name = "otp_28_1",
      version = "28.1",
      arch = "amd64",            # or "arm64"
      os = "ubuntu-24.04",       # must match the runtime's libc
      sha256 = "6f7a95250a83f999909cf64dc375fd08809eb057f61b24eecdf2b3b44fe621ab",
  )
  ```

  **On relocation.** An OTP installation is not relocatable: `ROOTDIR` is written
  into the generated start scripts at install time. A binary release ships an
  `Install` script precisely because of this, and `Install -cross <TARGET>` treats
  the current directory as the staging location while writing `TARGET` into the
  scripts. That is the split this rule needs, since staging happens in a sandbox
  and the install path is fixed and absolute. The rule fails with an explicit
  message if the archive has no executable `Install` at its root, because the
  likely mistake is passing an `otp_src` tarball, and the error from doing that
  otherwise surfaces deep inside the action.

  **On toolchain registration.** A prebuilt installation registers under the
  existing `:erlang_internal` constraint rather than a new one. It is hermetic in
  the same sense an internally built one is -- fetched and staged by the build,
  not discovered on the host -- and reusing the constraint keeps the generated
  target names identical. Moving a repository between the source and prebuilt
  paths is therefore a `MODULE.bazel` edit and nothing else: existing
  `toolchain_resolution_overrides` and `//<name>:toolchain_major` references keep
  resolving.

  **On multiple architectures.** Both tag classes take `exec_compatible_with`,
  whose values are appended to the generated toolchain's `exec_compatible_with`.
  A repository can register one prebuilt per execution architecture and let
  toolchain resolution choose, which is what makes a prebuilt OTP usable for
  something other than the machine that happens to be building.

## 3.19.0

A single fix, for a bug 3.18.0 introduced.

### Fixed

- **`@platforms` no longer has to be visible from the consumer**
  (`ct.bzl`, `eunit.bzl`, `eunit2.bzl`, `xref.bzl`, `xref2.bzl`, `dialyze.bzl`,
  `shell.bzl`, new `private/is_windows.bzl`).

  Nine `select()` keys named `@platforms//os:windows` as a bare string. A
  `select()` key written as a string resolves against the repo mapping of the
  package that *instantiates* it, and every one of these lives in a macro a
  consumer calls from its own `BUILD.bazel`. So the key resolved in the
  consumer's module, and any consumer that had not declared
  `bazel_dep(name = "platforms")` of its own failed analysis:

  ```
  ERROR: no such package '@@[unknown repo 'platforms' requested from @@]//os':
    No repository visible as '@platforms' from main repository
  ERROR: errors encountered resolving select() keys for //:xref
  ```

  Calling `xref`, `dialyze`, `eunit`, `ct_suite` or `shell` was enough to trigger
  it. The keys are now `Label`s, which resolve against this module's repo
  mapping, and `platforms` is declared here where it belongs.

  This was introduced in 3.18.0 by the migration away from
  `@bazel_tools//src/conditions:host_windows`. That question could not arise for
  the old key, because `bazel_tools` is an implicit dependency of every module
  and is visible everywhere. It survived release because the only consumers on
  hand both happened to depend on `platforms` already, this repository's own
  `test` module among them, so nothing in CI could see it. The regression test
  for it is a consumer that declares nothing but `rules_erlang`.

  The condition now lives in one place. Nine copies of a three-line `select()` is
  the shape of a fix that lands in some of them and not the rest, which is what
  happened to the `allow_empty` glob fix in 3.18.0.

### Compatibility

Drop-in for 3.18.0 and 3.16.0. No rule, macro, provider or attribute changed.

A consumer that declared `bazel_dep(name = "platforms")` only to satisfy 3.18.0
can drop it, though keeping it is harmless. One that uses `@platforms` in its own
`BUILD` files still needs it, for its own reasons.

Requires Bazel 8 or newer. Tested on Bazel 8.7.0 and 9.2.0.

## 3.18.0

First release from <https://github.com/bazelverse/rules_erlang>.

`rabbitmq/rules_erlang` is archived. `3.16.0` was its last release, and its
`main` branch stopped at an unreleased `4.0.0-beta.1`. This release continues the
3.x line from the **3.16.0 tag** and carries the fixes that were being maintained
downstream as a vendored copy. `4.0.0-beta.1` was never released or published to
the registry, and it resolves none of the fixes below; its commits remain
available from the archived upstream repository.

Every change is a separate commit, so `git diff 3.16.0..3.18.0` is exactly this
list and nothing else.

### Fixed

- **Skip system Erlang** (`repositories/erlang_config.bzl`). Honour
  `RULES_ERLANG_SKIP_SYSTEM=1`, so a build can use a hermetic toolchain instead
  of probing the host for an OTP install.

- **Portable tarball extraction** (`private/erlang_build.bzl`). `erlang_build`
  extracted the OTP tarball with GNU tar's `--transform`, which the bsdtar that
  macOS ships does not implement. Every Erlang target failed on macOS at
  `tar: Option --transform is not supported`, before compiling anything.

- **Allow empty globs in `erlang_app`** (`erlang_app.bzl`). `erlang_app` globs
  `include/`, `priv/`, `LICENSE*` and `.appup`, any of which a given Hex package
  may legitimately lack. Empty globs have been fatal since Bazel 7.

- **`erl_libs` priv directory** (`private/util.bzl`). `erl_libs_contents`
  accepted a tree artifact for `ebin` but not for `priv`. A rule that compiles a
  whole package in one action cannot enumerate `priv` in advance, so it had to
  drop the directory entirely.

- **`include_lib` self-reference** (`private/erlang_bytecode.bzl`). An app that
  `-include_lib`s its own public header could not resolve it, because
  `code:lib_dir/1` needs an `ebin` the action has not produced yet. grpcbox does
  this.

- **Migrate off the deprecated Windows condition** (`shell.bzl`, `eunit.bzl`,
  `eunit2.bzl`, `xref.bzl`, `xref2.bzl`, `dialyze.bzl`, `ct.bzl`). Nine
  `select()` keys move from `@bazel_tools//src/conditions:host_windows`, which
  Bazel warns about on every use, to the `@platforms//os:windows` constraint.

- **`dialyze` and `xref` under Bazel 8 and newer** (`private/ct.bzl`).
  `code_paths` prepended the dependency's `workspace_root` to a `short_path`
  that already encodes the repository, yielding
  `external/repo+/../repo+/pkg/ebin`. Bazel 7's runfiles tree contained a real
  `external` directory for the `..` to climb out of, so the redundant path
  happened to resolve. Bazel 8 lays repositories out as siblings, so it resolves
  nowhere and both rules fail with "No such file, directory or application".
  This affected every consumer using rules_erlang as a dependency, which is all
  of them.

- **Empty globs in `ct_suite` and `eunit`** (`ct.bzl`, `eunit.bzl`). The
  `allow_empty` fix above was applied to `erlang_app` only; eight globs across
  these two files still failed on any package lacking `include/`, a data
  directory, or test sources. Fatal since Bazel 7.

- **`app_file_test` under an external repository**
  (`private/app_file_test.bzl`). The analysis test asserted an exact
  `short_path`, which only holds when rules_erlang is the root module. Consumed
  as a dependency, the path carries a repository prefix and the test failed. A
  suffix match holds either way.

### Added

- **`bzlmod/hex_packages.bzl`**: `hex_packages_extension`, which declares a whole
  Hex closure from a data list plus a single hub repository of aliases.

  The existing model is one `hex_archive` per package, written into
  `MODULE.bazel` by hand. That does not scale to an application closure. An
  Ash/Phoenix app resolves to a few hundred packages, so `MODULE.bazel` grows a
  couple of thousand lines of generated boilerplate; every package then has to be
  named a second time in a `use_repo` call before anything can see it. The
  extension takes the closure as *data* and exports one hub repository, so the
  root module needs two lines and packages are depended on as `@<hub>//:<app>`.

  `hex_archive` is unchanged and still available.

### Removed

- **WORKSPACE support.** `WORKSPACE.bazel`, `WORKSPACE.bzlmod`,
  `internal_deps.bzl`, `internal_setup.bzl` and the `//:rules_erlang.bzl` entry
  point are gone, along with the `rules_erlang_dependencies`, `erlang_config` and
  `internal_erlang_from_*` macros they exported. Use the `erlang_config` module
  extension in `//bzlmod:extensions.bzl`, which has the same capabilities as tag
  classes.

  This is the only breaking change in the release, and it is unreachable on any
  supported Bazel: WORKSPACE is off by default in Bazel 8 and removed entirely in
  Bazel 9. A build still using it cannot be on a supported Bazel to begin with.

  `xref_runner_sources`, the one symbol the bzlmod path still needed from that
  file, moved to `//private:xref_runner_sources.bzl`.

### Changed

- **Dependencies moved to current stable**, which is what makes the ruleset build
  on Bazel 9 at all. rules_go 0.41.0 was the blocker: it uses `CcInfo`, removed in
  Bazel 9, and because `@go_toolchains//:all` is a registered toolchain that broke
  toolchain resolution for *every* target, not only the Go ones.

  | | from | to |
  | --- | --- | --- |
  | rules_go | 0.41.0 | 0.62.0 |
  | gazelle | 0.33.0 | 0.51.3 |
  | bazel_skylib | 1.7.1 | 1.9.2 |
  | rules_shell | - | 0.8.0 (new) |

  `sh_binary` and `sh_test` are no longer native rules, so they now load from
  `@rules_shell`. `compatibility_level` was dropped from `module()`; Bazel 9
  reports it as a no-op and warns on every build.

  gazelle stops at 0.51.3 rather than the current 0.52.2 because gazelle renamed
  its Go module to `github.com/bazel-contrib/bazel-gazelle/v2`. 0.51.x is the last
  release resolvable on the old import path. Moving further means migrating the
  Erlang plugin across a module rename and a major version.

- **The gazelle plugin's Go module** is now
  `github.com/bazelverse/rules_erlang`.

### Compatibility

For a bzlmod consumer, 3.18.0 is a drop-in replacement for 3.16.0: no rule,
macro, provider or attribute changed. The only removal is the WORKSPACE entry
point, which no supported Bazel can load anyway.

Requires Bazel 8 or newer, declared as `bazel_compatibility`. Tested on
Bazel 8.7.0 and 9.2.0.

### Note on where these fixes came from

They were maintained as a vendored copy of 3.16.0 inside a consuming repository.
That copy was **not** a faithful one. Neither divergence below is a change in
this release; both are recorded so the next person does not go looking for them
in the diff.

- Nine fixtures under `test/gazelle/testdata/` (`BUILD.out`, `contents.tar.gz`)
  were missing from it. The consuming repository's `.gitignore` matched `*.out`
  and `*.gz`, so they were dropped at check-in, silently, and nobody noticed for
  the life of the vendored tree. Rooting this branch at the 3.16.0 tag restores
  them by construction.
- `private/app_file_test.bzl` had been edited without being recorded in that
  copy's own change log. It is the `app_file_test` fix listed above.

Both are the sort of damage a ruleset can only take while it lives inside
somebody else's repository, which is much of why it no longer does.
