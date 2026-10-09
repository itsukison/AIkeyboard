# Actual Settings guide recordings

Captured October 8, 2026 using Computer Use for the Settings actions and
`xcrun simctl io … recordVideo --codec=h264` for native screen recording.
Source: iPhone 17 simulator, iOS 26.5, container bundle
`com.core7.keigobutton`, keyboard `com.core7.keigobutton.keyboard`.
The installed container build is 1.0.19 (22). No account was signed in and the
container app was not launched. Only the public app name was entered in Settings
search; no other text or AI request was used.

`recordings-2026-10-08/` preserves nine native movies, six native completed-state
PNG captures, and twelve Settings overview/search captures. Settings uses
Japanese, English, and Simplified Chinese in the
corresponding recordings. The keyboard's installed name remains 「敬語ボタン」.
Only the test simulator's preferences and keyboard state were changed; its
original preferred-language order, English followed by Japanese, is restored.

The source enablement movies finish with the keyboard on and Full Access off. The
separate Full Access movies start with the keyboard on, show the complete system
warning and Allow confirmation, and end with both switches on. The simulator
recorder retained the warning in its last frames even after dismissal, so the
ending uses a separately verified native screenshot of the completed state in
the same language. Enablement endings use native frames/captures with their
confirmed permission state. These are held frames from actual Settings, not
illustrated or reconstructed UI.

Updated October 9: both bundled guides start at the app's Settings page, matching
`UIApplication.openSettingsURLString`. The onboarding `keyboard-enable` guide
combines the native keyboard-enablement and Full Access recordings: tap Keyboards,
enable 「敬語ボタン」, enable Allow Full Access, confirm Allow, and return to practice.
The `keyboard-setup` recovery guide starts with the keyboard already enabled and
shows only the Full Access steps. Both finish with verified native screenshots
showing both switches on. The Settings-home/search captures remain preserved as
source material; manual navigation is explained in the app's rejected-open alert.

The edit recipe keeps actual navigation/toggle animation fragments, removes idle
time, holds relevant screens long enough to follow, and adds localized
instructions and purple tap markers. Subtitles use
white text on a black rounded background at 190/255 opacity (about 75%), with
16-pixel horizontal padding and a width determined by the text. The crop retains
the relevant controls and complete system warning. The system warning remains uncovered for
five seconds. Each guide ends with a return-to-app instruction. The clips do not
demonstrate the app's PiP itself.

Rebuild all six bundled files from the preserved captures:

```sh
python3 docs/assets/keyboard-enablement/prepare-recordings.py
```

Pillow, ffmpeg, and the referenced macOS Japanese/Chinese fonts are build-time
tools only. The script verifies the native ending's switch colors before encoding.
Outputs replace `iOS/Container/Resources/Videos/keyboard-enable-{ja,en,zh-Hans}.mp4`
and `keyboard-setup-{ja,en,zh-Hans}.mp4`: silent H.264, yuv420p, 666×990, 30 fps,
fast-start MP4; 15.5 seconds for combined onboarding setup and 13 seconds for
Full Access recovery. Their filenames and aspect ratio match the existing player.
Onboarding written steps and translations now explain both permissions, and
automatic continuation requires both current keyboard enablement and Full Access
detection. Explicit Skip and manual continuation remain available. Keyboard-only
return shows the remaining Full Access step; unconfirmed manual continuation is
not recorded as completed setup. The Settings navigation/PiP lifecycle is unchanged.

Validation of the previous clips completed October 8: all six clips visually checked for localized
labels, correct tap targets, separate enablement/Full Access states, complete
readable warnings, and correct endings. Every frame decoded successfully; ending
switch states also passed the color checks. The unsigned simulator app/extension
build succeeded, and all six packaged MP4s match the source assets byte for byte.
Real-device verification belongs to the user: both floating guides over Settings,
correct guide/language selection, looping/readability, fallback if PiP cannot
start, and clean return/permission detection. iOS versions with different Settings
layouts may differ from this iOS 26.5 footage; written instructions remain available.

October 9 validation: the six revised clips passed visual review, full decoding,
format/duration checks and final-state switch checks. The unsigned simulator
container/extension build succeeded for arm64 and x86_64. All six bundled videos
match the source outputs byte for byte, and the seven setup strings match their
English/Simplified Chinese translations in the built app. Physical-device PiP
and return-to-app permission detection remain unverified.
