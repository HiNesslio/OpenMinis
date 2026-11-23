# Butler: device-first iOS foundation (experimental)

Branch: feat/ondevice-butler-foundation. This is a first on-device working slice, not a finished 24/7 autonomous assistant.

## Wired into the app

- Home tools menu > Today · Personal Butler opens a native SwiftUI Today sheet.
- Separate permission prompts for the Apple Calendar and Reminders. User data is read through EventKit only after grant. No calendar writes.
- EventKit read permissions support iOS 16 using `requestAccess(to:completion:)` / `.authorized` and iOS 17+ using `requestFullAccessToEvents()` / `requestFullAccessToReminders()` / `.fullAccess`. Calendar write-only access is never treated as read authorization.
- Local relevance rules highlight near-future appointments with known locations, near-contiguous meetings, and reminders due soon.
- Living Memory records are explicitly user-confirmed and locally stored in an application-support JSON file with iOS file protection, delete controls and bounded length. They are not automatically synced.
- Local Memory → remote LLM prompt sharing is OFF by default; enabling it is a separate visible toggle. OpenMinis' session-level Memory switch must also be enabled.
- Optional on-device calendar notifications: scheduled 30 minutes ahead for already-read timed events, with cancellation and refresh reconciliation. They do not imply continuous iOS background execution.
- Completed assistant replies containing an entire fenced butler-card JSON block can render as safe native SwiftUI informational cards instead of Markdown.

## Structured answer format

Assistant content must contain only a fenced code block with info string `butler-card`, containing:

    {
      "version": 1,
      "kind": "agenda",
      "title": "Today",
      "summary": "Two items to review",
      "items": [
        { "title": "Meeting", "time": "09:30", "detail": "Office" }
      ]
    }

Allowed kinds: agenda, insights, summary. Maximum twelve rows. No model-generated UI actions, HTML, code, links or scripts. Oversized, streaming, unrecognized and malformed blocks fail closed to normal Markdown.

## Reference systems

- Meta Astryx: https://github.com/meta/astryx (React 19 / StyleX); reference chatbox composition, typography and interaction hierarchy only.
- Open Intelligent UI: https://github.com/thesysdev/open-intelligent-ui (React / OpenUI); reference the structured-response approach, not its JS renderer.
- OpenMinis runtime, existing tools and native SwiftUI chat remain intact. No React or remote UI gateway is required.

## Limitations and privacy

- Device-first is not the same as offline inference. If the existing configured LLM provider is online, opted-in prompt memory goes to that provider.
- Calendar and reminder data are used locally for Today and notifications but are not automatically added to the LLM prompt.
- Weather, traffic, routing, background signal collection, continuous background re-evaluation and dynamic Morning Briefing have NOT been connected.
- A change made to a calendar event while this app is closed will not automatically update its previously scheduled local notification.
- Notifications can appear on the lock screen, so the toggle is opt-in; the user can revoke them in iOS Settings.
- This branch has not been built on an actual Xcode runner yet. Native dependency build and test verification on macOS are required.
- Keep GPLv3 notices and downstream source distribution obligations when shipping a modified OpenMinis.

## iOS deployment compatibility

The Minis app target is iOS **16.0** (widget target 16.2), so shared Today SwiftUI and EventKit code cannot unconditionally invoke iOS 17 APIs. Use availability checks to select the appropriate EventKit authorization request and status. The SwiftUI view uses the iOS 16 `onChange(of:perform:)` single-value handler. Both iOS 16 and 17+ permission-purpose strings are present in `src/ios/Info.plist`.

When testing on a Mac with Xcode, verify an iOS 16 deployment target builds without availability diagnostics. On devices, separately verify the deny/grant/revoke flows for Calendar and Reminders on iOS 16 and iOS 17+. Swift source availability is checked statically in this branch, but full Xcode compilation and runtime permission behavior have **not** been verified here.

## On-device verification checklist

1. Build on macOS using upstream BUILDING.md and a physical iOS device.
2. Open Today; deny Calendar and Reminders, verify no private rows.
3. Grant Calendar only; verify agenda and local suggestions (no invented travel times).
4. Grant Reminders; verify upcoming incomplete due tasks.
5. Save and delete a confirmed preference, close and reopen Today; verify persistence.
6. Confirm memory-to-LLM sharing remains disabled until the explicit toggle is turned on.
7. Opt into local reminders; inspect a future event's pending notification; disable and check removal.
8. Feed a valid standalone butler-card to the assistant renderer; malformed payloads remain regular Markdown.
9. Run ButlerOnDeviceTests in the Minis XCTest target.

## Next on-device tasks

1. Context adapters for native WeatherKit and transport tools with freshness and provenance metadata.
2. Source-linked memory editing, expiration, contradiction handling and consent audit.
3. Proactive inbox and deterministic notification prioritization/quiet hours.
4. Daily briefing composition with truthful data-quality and permissions fallback.
5. Native chat composer polish inspired by Astryx and typed interactive response components.
6. Later, evaluate system BGTaskScheduler limits. No VPS or cloud infrastructure in this branch.