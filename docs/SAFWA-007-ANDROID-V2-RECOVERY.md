# SAFWA-007 — Android v2 embedding recovery (Kali)

## Evidence received (2026-10-19)

- Flutter **3.44.4** and Dart **3.12.2**, Android SDK **36.1**, JDK **21**.
- Android SDK licenses are not yet fully accepted.
- \`flutter devices\`: Linux and Chrome only; **no physical Android device or
  running Android emulator** confirmed.
- \`flutter build apk --debug\`: FAILED:
  \`Build failed due to use of deleted Android v1 embedding.\`
- A **159 MB APK dated October 18** still existed on disk. That APK is
  **stale and NOT evidence of a successful current Android build**.
- Flutter analyzer (0 issues), Flutter tests (18/18) and Quran fail-closed
  checks were previously reported passing on SAFWA-006.
- The local \`android/\`, \`ios/\`, \`pubspec.lock\` and a formatted test
  file were untracked or modified. Earlier local changes are stored in
  \`stash@{0}\`. Do not lose or pop the stash indiscriminately.

Flutter removed Android v1 embedding APIs from 3.29 onward.
Official Flutter note:
https://docs.flutter.dev/release/breaking-changes/v1-android-embedding

## Carefully prepare a fresh Android v2 scaffold

The existing \`android/\` is **untracked and exists only on Kali**, so this
GitHub branch cannot safely patch it directly. Use the recovery script.

\`\`\`bash
cd ~/Safwa-Quran
git pull --ff-only
git status --short --branch
bash scripts/android_v2_recovery.sh inspect
bash scripts/android_v2_recovery.sh prepare
\`\`\`

Prepare copies \`android/\` into an ignored \`.staging/\` recovery session,
generates a new Flutter Android project with project name
\`safwa_quran\` / provisional org \`org.safwa.institute\`, and validates
the generated platform sources. **It does not touch live \`android/\`.**

Review the difference between:
- \`.staging/android-v2-recovery/session-.../original-android\`
- \`.staging/android-v2-recovery/session-.../template/android\`

Do not blindly replace an Android folder with custom application IDs,
production signing/keystores, permissions, notification integrations,
Firebase configuration, icon/name resources or native Android code.
Native app identity matters for upgrades and publishing.

Only after reviewing the generated platform and backup, execute the
specific **opt-in** command printed by prepare, e.g.

\`\`\`bash
bash scripts/android_v2_recovery.sh apply \
  "/home/ahmadib/Safwa-Quran/.staging/android-v2-recovery/session-XXXXXXXX"
\`\`\`

Apply refuses local changes made since preparation, saves the old project
inside that session, and installs the new Android platform directory.
Do not manually delete old \`android/\` without a backup.

## Device build gate (still not yet passed)

\`\`\`bash
flutter doctor --android-licenses
flutter clean
flutter pub get
flutter analyze
flutter test
python3 scripts/quran_pipeline.py check
flutter build apk --debug
# Check *fresh* modification time/sha for the resulting file:
stat -c '%y %s bytes %n' build/app/outputs/flutter-apk/app-debug.apk
sha256sum build/app/outputs/flutter-apk/app-debug.apk
flutter devices
git status --short --branch
git stash list
\`\`\`

If an Android device is unavailable, build verification can still proceed
on Kali without running the app. For a device smoke test, use an authorized
USB Android phone with developer/USB-debugging enabled, or a configured
Android emulator. Do not infer test-device availability.

No Android artifacts or native files are automatically committed, merged,
or distributed by this script. Quran text assets and release policy remain
**blocked**; 0/2 scholarly approvals verified.
