#!/bin/sh
set -eu
STORMY_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STORMY_OUTPUT="$STORMY_ROOT/temp/native-tests"
mkdir -p "$STORMY_OUTPUT"
xcrun clang -fobjc-arc -framework Foundation \
  -I "$STORMY_ROOT/packages/stormy_gromore/ios/Classes" \
  "$STORMY_ROOT/packages/stormy_gromore/ios/Classes/StormyRewardTerminalState.m" \
  "$STORMY_ROOT/packages/stormy_gromore/test/native/ios_reward_terminal_state_test.m" \
  -o "$STORMY_OUTPUT/ios_reward_terminal_state_test"
"$STORMY_OUTPUT/ios_reward_terminal_state_test"
