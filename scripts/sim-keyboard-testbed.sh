#!/bin/bash
# Puts a booted simulator into a state where the 敬語ボタン keyboard can actually
# be exercised: keyboard installed AND enabled without walking Settings, software
# keyboard forced on (the Mac's hardware keyboard normally suppresses it), and the
# app parked on whichever onboarding page you want to test.
#
#   ./scripts/sim-keyboard-testbed.sh <simulator-udid> [onboarding-page-index]
#
# Page indices: 6 = switch practice, 7 = rewrite practice, 8 = reply practice.
# After it runs, one gesture is still yours: long-press the globe key and pick
# 敬語ボタン. iOS keeps the selected input mode in state that is not writable
# from outside, so that pick cannot be scripted.
set -euo pipefail

UDID="${1:?usage: sim-keyboard-testbed.sh <udid> [page-index]}"
PAGE="${2:-6}"
APP_ID="com.core7.keigobutton"
KBD_ID="com.core7.keigobutton.keyboard"
# The destination matters: without it, -showBuildSettings reports the *device*
# products dir and the install silently puts an iphoneos build on the simulator,
# which then fails to launch.
DERIVED="$(xcodebuild -project KeigoButton.xcodeproj -scheme KeigoButton \
  -destination "platform=iOS Simulator,id=$UDID" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2; exit}')"

echo "▸ installing $DERIVED/KeigoButton.app"
xcrun simctl install "$UDID" "$DERIVED/KeigoButton.app"

echo "▸ enabling the keyboard (no Settings navigation)"
xcrun simctl spawn "$UDID" defaults write .GlobalPreferences AppleKeyboards -array \
  "en_JP@sw=QWERTY;hw=Automatic" \
  "ja_JP-Kana@sw=Kana;hw=Automatic" \
  "ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic" \
  "emoji@sw=Emoji" \
  "$KBD_ID"

echo "▸ detaching the hardware keyboard so the software one shows"
# Device runtime state, not a Simulator.app preference — writing
# ConnectHardwareKeyboard into com.apple.iphonesimulator does NOT work.
HELPER="$(mktemp -d)/hwkbd"
cat > "$HELPER.m" <<'OBJC'
#import <Foundation/Foundation.h>
#import <dlfcn.h>
int main(int argc, char **argv) {
    @autoreleasepool {
        dlopen("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator", RTLD_NOW);
        id ctx = [NSClassFromString(@"SimServiceContext")
            performSelector:@selector(sharedServiceContextForDeveloperDir:error:)
                 withObject:@"/Applications/Xcode.app/Contents/Developer" withObject:nil];
        id set = [ctx performSelector:@selector(defaultDeviceSetWithError:) withObject:nil];
        NSString *wanted = [NSString stringWithUTF8String:argv[1]];
        for (id device in [set performSelector:@selector(devices)]) {
            NSString *udid = [[device performSelector:@selector(UDID)] performSelector:@selector(UUIDString)];
            if (![udid.lowercaseString isEqualToString:wanted.lowercaseString]) continue;
            SEL sel = @selector(setHardwareKeyboardEnabled:keyboardType:error:);
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[device methodSignatureForSelector:sel]];
            [inv setSelector:sel]; [inv setTarget:device];
            BOOL enable = NO; unsigned int type = 0; NSError *__autoreleasing e = nil, *__autoreleasing *ep = &e;
            [inv setArgument:&enable atIndex:2]; [inv setArgument:&type atIndex:3]; [inv setArgument:&ep atIndex:4];
            [inv invoke];
            return 0;
        }
        return 1;
    }
}
OBJC
clang -fobjc-arc -Wno-objc-method-access -framework Foundation -o "$HELPER" "$HELPER.m"
"$HELPER" "$UDID"

echo "▸ parking the app on onboarding page $PAGE"
xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
xcrun simctl spawn "$UDID" defaults write "$APP_ID" "aikJP.hasCompletedFirstRun" -bool NO
xcrun simctl spawn "$UDID" defaults write "$APP_ID" "aikJP.onboardingVersion" -string "interactive_v3"
xcrun simctl spawn "$UDID" defaults write "$APP_ID" "aikJP.interactiveOnboardingStarted" -bool YES
xcrun simctl spawn "$UDID" defaults write "$APP_ID" "aikJP.interactiveOnboardingPageIndex" -int "$PAGE"
xcrun simctl launch "$UDID" "$APP_ID" >/dev/null

cat <<EOF

Ready. Remaining manual step: long-press the globe key → choose 敬語ボタン.

Watch the detection decide, live:
  xcrun simctl spawn $UDID log stream --style compact \\
    --predicate 'eventMessage CONTAINS "switch-probe" OR eventMessage CONTAINS "reply-pill"'

Note: Full Access is a per-install grant, so reinstalling clears it. The reply
page reads it from the value the *extension* writes to the App Group, so it also
reads "needs Full Access" until the keyboard has come up once after an install.
EOF
