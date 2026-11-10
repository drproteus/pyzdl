#!/bin/sh
# Builds pyZDL on macOS or Linux. Run it on the target OS: PureBasic only builds
# for the platform it runs on from the command line.
#
#   sh purebasic/build.sh               build and run the unit tests
#   sh purebasic/build.sh --skip-tests  build only
#
# Set PUREBASIC_COMPILER to the pbcompiler path if it is not on PATH.

set -eu
cd "$(dirname "$0")"

PBC="${PUREBASIC_COMPILER:-pbcompiler}"
mkdir -p build

"$PBC" pyzdl.pb --output build/pyZDL

if [ "${1:-}" != "--skip-tests" ]; then
  "$PBC" tests/tests.pb --output build/tests
  ./build/tests
fi

echo "Built purebasic/build/pyZDL"
