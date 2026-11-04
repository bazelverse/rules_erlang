#!/usr/bin/env bash
set -euo pipefail

out="$(cat "$1")"
case "$out" in
"fake erl at /"*/private/otp_tree_test/fake_otp/bin/erl) ;;
*)
    echo "erl did not run from the tree: $out" >&2
    exit 1
    ;;
esac
