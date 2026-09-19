module github.com/bazelverse/rules_erlang/test

go 1.25.0

require (
	github.com/bazelbuild/bazel-gazelle v0.51.3
	github.com/bazelbuild/rules_go v0.62.0
	github.com/bazelverse/rules_erlang v0.0.0-00010101000000-000000000000
	github.com/emirpasic/gods v1.18.1
	github.com/ghodss/yaml v1.0.0
	github.com/onsi/ginkgo/v2 v2.7.0
	github.com/onsi/gomega v1.25.0
)

require (
	github.com/bazelbuild/buildtools v0.0.0-20250930140053-2eb4fccefb52
	gopkg.in/yaml.v2 v2.4.0 // indirect
)

require (
	github.com/bazel-contrib/bazel-gazelle/v2 v2.0.0-2 // indirect
	github.com/bmatcuk/doublestar/v4 v4.9.1 // indirect
	github.com/go-logr/logr v1.2.3 // indirect
	github.com/google/go-cmp v0.6.0 // indirect
	golang.org/x/mod v0.35.0 // indirect
	golang.org/x/net v0.55.0 // indirect
	golang.org/x/sys v0.45.0 // indirect
	golang.org/x/text v0.37.0 // indirect
	golang.org/x/tools/go/vcs v0.1.0-deprecated // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

// The plugin under test is this repository; Bazel resolves it by label, and this
// keeps a plain `go build` in this directory consistent with that.
replace github.com/bazelverse/rules_erlang => ../
