# Erlang Gazelle plugin

This directory contains a plugin for [Gazelle](https://github.com/bazelbuild/bazel-gazelle) that generates and updates BUILD files for erlang code.

This plugin is currently based on the [rules_python implementation](https://github.com/bazelbuild/rules_python/tree/main/gazelle).

## To use

In `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_erlang", version = "3.18.0")
bazel_dep(name = "gazelle", version = "0.40.0")

erlang_config = use_extension(
    "@rules_erlang//bzlmod:extensions.bzl",
    "erlang_config",
)
use_repo(erlang_config, "erlang_config")

register_toolchains("@erlang_config//external:toolchain")
```

And a `BUILD` file with:

```starlark
load("@bazel_gazelle//:def.bzl", "gazelle")
load("@rules_erlang//gazelle:def.bzl", "GAZELLE_ERLANG_RUNTIME_DEPS")

gazelle(
    name = "gazelle",
    data = GAZELLE_ERLANG_RUNTIME_DEPS,
    gazelle = "@rules_erlang//gazelle:gazelle_erlang_binary",
)
```

Then run `bazel run //:gazelle`

## Directives

- `erlang_resolve`

  Example: `# gazelle:erlang_resolve rabbit_common @rabbitmq-server//deps/rabbit_common:erlang_app`

  Purpose: Provides explicit resolution from an erlang application name to it's label

- `erlang_module_source_lib`

  Example: `# gazelle:erlang_module_source_lib Elixir.RabbitMQ.CLI.CommandBehaviour:rabbitmq_cli`

  Purpose: Indicates which erlang application contains a given module, irrespective of `moduleindex.yaml`

- `erlang_exclude_when_rule_of_kind_exists`

  Purpose: Tells the erlang extension for gazelle to skip rule generation for a given directory, if a BUILD file already exists and contains a rule of this type

- `erlang_generate_beam_files_macro`

  Example: `# gazelle:erlang_generate_beam_files_macro`

  Purpose: Tells the erlang extension to generate `app.bzl` and define all of the rules for compiling beam files within it. This allows for a much more compact BUILD file

- `erlang_generate_fewer_bytecode_rules`

  Purpose: Tells the erlang extension to generate rules that compile byte code in up to 3 phases (parse transforms, behaviours, the rest) instead of generating a rule per beam file (the default). This can provide a speed boost for some projects, such as rabbitmq-server, which is an umbrella project with many sources and applications.

- `erlang_always_generate_test_beam_files`

  Purpose: Tells the erlang extention to generate the rules that compile source for test, even if the application contains no test suites

- `erlang_skip_rules`

  Example: `# gazelle:erlang_skip_rules assert_suites2,xref,plt,dialyze
`

  Purpose: Tells the erlang extension not to generate rules of these types

- `erlang_apps_dirs`

  Example: `# gazelle:erlang_apps_dirs deps`

  Purpose: Tells the erlang extension too look in additional directories within the project in addition to `apps` for local applications. Only useful for umbrella repos.

- `erlang_app_testonly`

  Purpose: Sets `testonly = True` on the rules generated. Useful for marking a test dependency as something that should not be shipped.

- `erlang_app_dep`

  Purpose: An erlang application name to add as a depencency, in addition to the detected deps

- `erlang_app_dep_ignore`

  Purpose: Ignores a detected dependency entirely, both for compilation and runtime

- `erlang_app_dep_exclude`

  Example: `# gazelle:erlang_app_dep_exclude rabbitmq_cli`

  Purpose: Excludes a detected dependency from the generated `.app` file for an app, useful for optional dependencies

- `erlang_app_path_ignore`

  Purpose: Exclude files matching the pattern from an `erlang_app` rule and its sources

- `erlang_app_extra_app`

  Purpose: Inject an additional application into the `.app` file, under the `applications` key

- `erlang_no_tests`

  Purpose: Don't generate rules associated with tests. Useful for dependencies

- `erlang_erlc_opt`

  Example: `# gazelle:erlang_erlc_opt -DBUILD_WITHOUT_QUIC`

  Purpose: Adds additional values to the `erlc_opts` rule. Useful as it applies when parsing sources to determine dependencies
