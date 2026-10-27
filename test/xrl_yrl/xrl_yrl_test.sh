#!/usr/bin/env bash
set -euo pipefail

grep -q -- '-module(lexer).' "$1"
grep -q -- '-module(parser).' "$2"
