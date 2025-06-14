#!/bin/env bash

LUA54="${LUA:-lua5.4}"

fail() {
	rm -f /tmp/rollmeow-test.cache.lua

	echo "[FAIL]"
	echo "$1"
	exit 1
}

verify() {
	local tcase="$1"
	local stdout="$2"
	local stderr="$3"

	if [ -f "$tcase.out" ]; then
		if ! cmp -s "$stdout" "$tcase.out"; then
			fail "$stdout and $tcase.out differs"
		fi

		if ! cmp -s "$stderr" "$tcase.err"; then
			fail "$stderr and $tcase.err differs"
		fi
	else
		if ! "$LUA54" match.lua "$stdout" "$tcase.rout"; then
			fail "$stdout doesn't match $tcase.rout"
		fi

		if ! "$LUA54" match.lua "$stderr" "$tcase.rerr"; then
			fail "$stderr doesn't match $tcase.rerr"
		fi
	fi
}

runcase() {
	local tcase="$1"
	local cmd="$ROLLMEOW --sync --conf $tcase.lua"

	if [ -f "$tcase.sh" ]; then
		cmd="sh $tcase.sh"
	fi

	if [[ "$tcase" =~ ^unit- ]]; then
		initenv="env LUA_INIT=package.path=package.path..';$SRCDIR/?.lua'"
		cmd="$initenv $LUA54 $tcase.lua"
	fi

	dir="$(mktemp -d)"
	local stdout="$dir/stdout"
	local stderr="$dir/stderr"

	$cmd >"$stdout" 2>"$stderr"

	verify "$tcase" "$stdout" "$stderr"

	rm -rf "$dir" /tmp/rollmeow-test.cache.lua
}

testcases=(
	invalid-followed-package
	uncached-followed-package
	invalid-package-type-follow-and-regex
	batched-package-with-url
	# Regression tests
	sync-manual-checked-package
	sync-git-strip-trailing-newline
	# unit tests
	unit-version-cmp
	unit-pktline)

export ROLLMEOW="$(dirname "$0")/../src/rollmeow"
export SRCDIR="$(dirname "$0")"/../src/
export TESTDIR="$(dirname "$0")"

for c in "${testcases[@]}"; do
	printf "Running $c... "
	runcase "$c"
	echo "[OK]"
done
