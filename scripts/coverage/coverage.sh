#!/usr/bin/env bash
#
# VivaDicta code coverage from the terminal.
#
#   coverage.sh app [File.swift ...]   Full test plan in the simulator (canonical).
#                                      Prints overall + per-target, plus per-file rows
#                                      for any named files (e.g. ChatViewModel.swift).
#   coverage.sh module <Module>        One SPM module via `swift test` (fast, macOS host).
#
# Env:
#   DESTINATION   override the simulator destination
#                 (default 'platform=iOS Simulator,name=iPhone 17 Pro Max').
#   RESULT        override the .xcresult path (default /tmp/vivadicta-cov.xcresult).
#
# Coverage is a RUNTIME metric: this runs the tests, then reads the result. There is
# no way to get real coverage by reading the codebase (that is the LOC ratio - see the
# loc-report skill).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro Max}"
RESULT="${RESULT:-/tmp/vivadicta-cov.xcresult}"
MODE="${1:-app}"

case "$MODE" in
  app)
    shift || true
    rm -rf "$RESULT"
    echo "Running full test plan with coverage (first-party targets only)..."
    xcodebuild test -scheme VivaDicta \
      -workspace ./VivaDicta.xcodeproj/project.xcworkspace \
      -testPlan VivaDictaTestPlan \
      -destination "$DESTINATION" \
      -enableCodeCoverage YES -resultBundlePath "$RESULT" 2>&1 | tail -3

    echo
    echo "=== OVERALL ==="
    xcrun xccov view --report --json "$RESULT" \
      | python3 -c "import json,sys; d=json.load(sys.stdin); print('%.2f%% (%d/%d lines)' % (d['lineCoverage']*100, d['coveredLines'], d['executableLines']))"

    echo
    echo "=== PER-TARGET ==="
    xcrun xccov view --report --only-targets "$RESULT"

    if [ "$#" -gt 0 ]; then
      echo
      echo "=== PER-FILE ==="
      for f in "$@"; do
        xcrun xccov view --report "$RESULT" 2>/dev/null | grep -i "$f" \
          || echo "  (no row for '$f' - it may be statically merged into another target; see caveats)"
      done
    fi
    ;;

  module)
    MODULE="${2:?usage: coverage.sh module <Module>}"
    cd "Modules/$MODULE"
    # Capture swift test's own exit status (not the pipe's) so a failing build
    # aborts instead of silently reporting stale coverage from a prior .build.
    log="${TMPDIR:-/tmp}/coverage-module-$$.log"
    if ! xcrun swift test --enable-code-coverage > "$log" 2>&1; then
      grep -iE "error:|Test run with" "$log" >&2 || true
      echo "swift test failed for $MODULE - aborting so coverage is not reported from a stale build." >&2
      rm -f "$log"
      exit 1
    fi
    grep -iE "Test run with" "$log" || true
    rm -f "$log"
    BIN="$(find .build -name "${MODULE}PackageTests" -type f -path '*MacOS*' | head -1)"
    PROF="$(find .build -name default.profdata | head -1)"
    if [ -z "$BIN" ] || [ -z "$PROF" ]; then
      echo "Could not locate test binary / profdata under .build (did the build fail?)." >&2
      exit 1
    fi
    echo
    echo "=== $MODULE (production sources only) ==="
    xcrun llvm-cov report "$BIN" -instr-profile="$PROF" \
      -ignore-filename-regex='Tests|\.build|Mocks' "Sources/$MODULE/"
    ;;

  *)
    echo "usage: coverage.sh app [File.swift ...] | coverage.sh module <Module>" >&2
    exit 2
    ;;
esac
