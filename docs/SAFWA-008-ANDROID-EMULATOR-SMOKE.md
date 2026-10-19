# SAFWA-008 — Android emulator smoke gate

Evidence supplied 2026-10-19: Safwa's Android v2 migration built a fresh
150507531-byte debug APK, SHA-256
95d2bbfc70898abca8065681448d4ebc7d3ed794c9b729cca5e1cc1b5031b077.
Flutter analyzer had zero issues, 18/18 Flutter tests passed, and the Quran
reader/source release policy remained fail-closed.

The Android v2 app manifest and MainActivity are present. The user confirmed
one API-34 AVD exists named OneCall_Kaduna_API_34, but flutter devices still
lists only Linux and Chrome. An emulator exists but is NOT running yet.

Run on Kali:

    cd ~/Safwa-Quran
    git pull --ff-only
    flutter emulators --launch OneCall_Kaduna_API_34
    adb devices -l
    flutter devices
    bash scripts/android_emulator_smoke.sh inspect
    bash scripts/android_emulator_smoke.sh run emulator-5554

Replace emulator-5554 with the REAL running emulator-XXXX serial returned
by adb devices. Script will refuse a physical phone, unknown package ID,
non-v2 manifest, absent APK, or unbooted emulator. It only installs/launches
a debug APK when expressly invoked with the emulator serial; no secret
permissions, Quran content, app-store publication or remote transmission.
Private screenshot and APK digest are stored under ignored .staging/.

Manual acceptance on emulator: home opens; Surah shows Verified Mushaf
required without Arabic content; Prayer Times renders all five and
Sunrise; switch cities, method and Asr rule, then verify saved preferences
after reboot. Compare prayer calculations with trusted local mosque
timetables (not yet validated). Qibla true-north bearing isn't a compass.
Salah journaling, Tasbih, calendar estimate, learning, language preference
and local data deletion should be exercised. Prayer reminders are settings
only: NO OS notifications are scheduled. Adhkar and recitation libraries
remain source/rights gated. Test accessibility and small screens.

Source-control blocker: the generated Android directory is UNTRACKED.
Do not commit android/local.properties, .gradle caches, generated plugin
registrants, keys, certificates or environment credentials. Inspect
application ID, Gradle/wrapper, Kotlin, manifests, icons, permissions and
debug/release signing, then stage only reviewed reproducible platform
source and appropriate lockfiles. A fresh-clone CI Android build remains
required before Android is declared reproducible.

PRs remain draft/unmerged; Quran reader OFF; public release OFF;
scholarly approvals 0/2 verified. Device smoke does not waive those gates.
