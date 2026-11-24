# Personal Agent V2 — Product & Implementation Blueprint

Status: **P0 implementation in progress on this branch; device build/runtime verification pending.**
Base: `feat/ondevice-butler-foundation` (existing buildable Butler prototype; actual Xcode validation remains device-local).
Working branch: `feat/personal-agent-v2`.

## P0 implementation checkpoint (2026-11-24)

This branch now contains code changes, not just a design:

- The Today UI is presented as a **native, collapsible context card at the top of every local chat**, below navigation/status banners and above the message transcript, with the existing composer unchanged at the bottom. It is not yet a persisted chronological ChatStore message; implementing durable inline cards in the virtualized collection-view transcript remains follow-up work.
- The original separate Today toolbar sheet entry has been removed; a fresh empty install with Auto launch opens a new chat. Returning sessions and explicit launch settings remain intact.
- Actual AI call: \`ButlerAIBriefingService.analyze\` in \`ButlerOnDevice.swift\` uses the selected OpenMinis \`AgentProvider.streamAgentMessage\` with **no tools**, \`thinkingLevel: .off\`, and a bounded JSON snapshot of authorized EventKit and Reminders facts. Its result is validated, source-reference IDs must be from the deterministic local insights, and any failure falls back to the deterministic briefing. **No AI request occurs without the explicit "允許 AI 分析今日行程" switch** (stored locally as \`butlerAIBriefingConsent\`; default off). The model still produces prose, which must be treated as an AI suggestion, not independently verified fact.
- The chat top inset measures the **combined** scheduled-task banner and Today strip for iOS 26 compatibility. The first-run Linux directory onboarding is removed from the Personal UX.
- Personal Mode defaults on as a **presentation preference**. All enabled Shell/Python, file, browser and subagent tools remain available to the model, while technical tool capsules, folded summaries, floating execution previews and reasoning blocks are hidden. The setting "顯示進階工具介面" reveals debug UI, not additional execution permissions.
- The Personal Settings entry now opens a **native curated Connections Marketplace** (nine official/native starter entries), with search, installed status, MCP OAuth handoff and Skill source preview/confirmed import. Public Registry search remains a later phase. See the Marketplace document.
- \`ButlerOnDeviceTests.swift\` includes new pure JSON validation tests; Xcode/device compile and permission behavior have not been independently verified here.

Known limits and next steps:
1. No persistent native card records in ChatStore; the Today strip is displayed **within** the chat UI, but is not a normal chronological message bubble.
2. No durable AI briefing cache across chat sessions; entering multiple conversations after opting in may make repeated paid LLM calls. A per-source/model freshness cache is needed before wider release.
3. Active-time/local notification only. iOS cannot guarantee that suspended app code runs AI periodically. Server/APNs optional later.
4. Marketplace P0 now supports a curated, reviewed catalog and existing OAuth/Skill import flows; live MCP Registry/Skills directories, automated capability audits and full per-tool authorization remain P1/P2.
5. Personal Mode only hides technical UI; original per-tool toggles, permission checks, confirmations and audit remain in force. Review separately installed MCP capabilities before trusting them.
6. Review accessibility, keyboard/scroll ergonomics on physical iPhone and iPad, iOS 16 minimum, signing, offline response and error states.

To fetch **this** branch while keeping the original Butler branch:

\`\`\`bash
cd ~/Downloads/OpenMinis-Butler
git status --short
git fetch origin feat/personal-agent-v2
git switch --track origin/feat/personal-agent-v2
# If the local branch already exists: git switch feat/personal-agent-v2 && git pull --ff-only
\`\`\`

Do not discard local Personal Team signing configuration or uncommitted files with \`git reset --hard\`. In Xcode choose Minis on a physical iPhone, Clean Build Folder, then Run. The native iSH/FFmpeg/Rclone binaries do not need rebuilding just for Swift code changes.

Manual smoke check: open app on new install -> inline Today card in chat -> grant Calendar and Reminders -> baseline reflects actual data -> opt into AI analysis -> model returns a short AI summary, with no shell tool blocks -> collapse Today, send an ordinary chat message -> confirm composer/draft, Session History and notification preference still work -> toggle advanced UI -> verify technical traces are hidden/shown without changing available model tools. Disable calendar permission in iOS Settings and re-open the app; stale private events/analysis must not remain visible.

## Product promise

OpenMinis is the underlying runtime, not the product users must learn. The product should behave as a privacy-aware personal assistant: it understands calendar, reminders and explicitly connected sources; highlights what matters; communicates through native cards *in the conversation*; and requests permission before taking actions.

**User-facing vocabulary:** Today, Chat, Connections, Memory, Notifications, Settings. **Advanced vocabulary hidden by default:** MCP, Skills, shell, Python, iSH, Linux, token budgets, model groups, sub-agents, raw tool traces, environment variables.

### New default shell

- Main screen: a **single chat-first surface**, including a compact inline "Today" briefing as the first content (not a separate full-screen feature sheet).
- At the top: date + the top 1–3 actionable insights, with source/freshness and sensible empty/permission states.
- Conversation beneath: ask a question, respond to an insight, accept an action proposal, or open a connected card. No visible tool invocation details by default.
- Connections: a curated catalog of integrations and capabilities, not separate manual MCP vs Skills choices. Entry cards show what they do, data they read, whether write actions are supported, and a Connect/Enable action.
- Settings: General, AI & Privacy, Notifications, Connections, About. "Developer" / "Advanced" is an explicitly enabled separate section, not removed from the underlying app.

Avoid "AI Generated" badges and gratuitous decorative cards. Cards must have semantic content, compact typography, native dynamic type, dark mode and VoiceOver.

## Current code — observed

- `src/ios/Views/ContentView/ButlerOnDevice.swift`: deterministic `ButlerDecisionEngine`, `ButlerBriefingComposer`, `ButlerTodayView`, local confirmed Living Memory, simple `butler-card` decoder.
- `src/ios/Views/ContentView/ButlerLocalNotifications.swift`: opt-in local notifications from known calendar event start minus 30 minutes. No persistent background intelligence.
- `src/ios/Views/Chat/AssistantBlockView.swift`: current message block renderer, including text and developer-oriented tool/thinking blocks.
- `src/ios/Agent/Chat/AIChatViewModel+SystemPrompt.swift`: explicitly prioritizes shell commands and developer tools; must have a separate Personal Mode prompt.
- `src/ios/Agent/Chat/AIChatViewModel+ToolDefinitions.swift`: default `makeAgentTools()` retains shell/file/browser tooling. Personal Mode filters presentation, not model capabilities; normal permission and write confirmation gates remain essential.
- `src/ios/Agent/Chat/AIChatViewModel+ProgrammaticPrompt.swift`: robust serialized programmatic prompt entry; useful for *explicit* agent jobs, but unsuitable for silently treating every brief as a user-authored message.
- `src/ios/Views/Settings/SettingsSheet.swift`, `src/ios/Views/MCP/MCPIntegrationsView.swift`, `src/ios/Views/Skills/SkillsManagementView.swift`: technical management UIs and existing registry/stores to reuse.
- `src/ios/MinisApp.swift`: FileProvider and background lifecycle integration. Personal Team signing has no App Group entitlement; platform features must retain guarded fallback paths.

## Architecture

```text
Authorized sources: EventKit / Reminders / opt-in app memory / installed Connections
                |
          Context Adapters
     normalize + timestamp + consent + provenance
                |
      Relevance & Policy Engine (on-device, deterministic)
     trigger, dedup, priority, privacy, quiet hours
                |
    +-----------+-------------------+
    |                               |
    v                               v
Briefing AI service            Local Notification Planner
approved minimal facts         deterministic, scheduled
    |                               |
    v                               v
Validated typed response      Notification/deep link to insight
    |
    v
Native SwiftUI Card Renderer <-> Chat timeline
    |
Whitelist action dispatcher -> permission/confirmation -> native capability/MCP
```

The LLM is for analysis, explanation and prioritization, **not** to manufacture facts. Facts and timestamps come from local adapters. The deterministic layer evaluates urgency, deduplication and eligibility before asking a model. LLM unavailable / consent denied = still display useful factual briefing and reminders.

### Context payload (no raw entire calendar upload)

```json
{
  "schema_version": 1,
  "generated_at": "ISO8601",
  "timezone": "Asia/Macau",
  "sources": [{"id":"calendar", "last_read_at":"ISO8601","permission":"read"}],
  "facts": [
    {"id":"event:local-id", "type":"calendar_event", "title":"Appointment",
     "start":"ISO8601", "end":"ISO8601", "location":null,
     "source":"eventkit", "expires_at":"ISO8601"}
  ],
  "private_memory_consent": false
}
```

The schema is illustrative; do not hard-code timezone, source values or IDs. Local-only is the default. Ask for explicit consent before sending calendar/location/memory summaries to an online LLM. Bound payload sizes and redact secrets. The currently configured provider and credentials can be reused with a narrowly scoped `PersonalBriefingService` instead of routing through a full command-executing agent turn.

### Intelligence UI contract

Native SwiftUI views from validated, versioned JSON. The model **never** returns arbitrary executable Swift, JSX, HTML, JS or URL actions.

Suggested `PersonalCard`:
- `agenda`: schedule and conflicts.
- `reminder`: due, snooze, mark complete (confirmation and EventKit permission as needed).
- `insight`: evidence-backed issue, reason, priority, provenance.
- `choices`: a few suggestions with explicit actions.
- `route`: transport candidate and departure information **only with trusted, fresh source** (future ParkGo connection).
- `weather`: observed alert and forecast **only if a weather adapter exists**.
- `confirmation`: irreversible/write action requires explicit user review.
- `connection`: "connect service" / "permission needed" state.

All cards: unique ID, source IDs, observed time, expiry/stale indication, stable action IDs, fallback plain text. Parse limits and escaping. Whitelisted `ActionDispatcher` executes only known native actions with fresh authorization and user confirmation. Streaming incremental rendering can come after fully decoded stable cards; never expose unvalidated partial actions.

Model responses can coexist with ordinary text in one chat message. Persist card metadata in the chat DB, not as fragile Markdown fenced blocks only. The existing `butler-card` renderer is a transitional proof of concept, **not the target protocol**.

### Real AI Today, not a rules-only sheet

1. User opens app; fetch consented EventKit/Reminders and other connected sources in parallel.
2. Normalize facts, detect what changed, and create a factual deterministic baseline.
3. If user enabled AI Briefing and permitted sharing with the chosen provider, summarize a *minimal relevant subset* using the existing configured LLM. Otherwise display baseline.
4. AI output must identify which facts support each suggestion; do not invent route times, weather, location, preferences, or event details. Validate outputs and gracefully revert to baseline on failure.
5. Insert or update a system-owned Today insight message near the top of chat. Do **not** submit a fake user message, overwrite composer drafts, or break chat turn ordering.
6. Tap any insight to ask follow-ups in chat, or use a native action with permissions.

Quality goals: relevant, concise, low repetitive alerts, clear "why am I seeing this" and source freshness; maximum 3 priority cards on initial view, "show more" for low priority.

## Proactive assistance: three reliability levels

1. **While app is active:** foreground refresh / EventKit change signals trigger recalculation and optional AI analysis; no guarantee every signal should notify.
2. **With app suspended/not active:** schedule local notifications based on known event/reminder times, including cancellation/edit reconciliation when next opened. `BGTaskScheduler` is best effort; do not promise exact wake time or persistent inference.
3. **Truly timely external monitoring:** optional server-side observer + APNs for events from connected remote services (e.g. ParkGo live transport disruptions). Require separately scoped opt-in, retention rules and explicit consent. A VPS is NOT required for MVP chat/briefing/local alerts, but is needed for dependable server-based monitoring when the app is not executing.

Trigger gates: consent, trusted source, freshness, importance, duplicate suppression, quiet hours, user-defined preferences, frequency cap, one-click mute. Notification taps open an existing insight/card thread; never auto-run write actions.

## Personal Mode and Advanced Mode

Personal Mode is the default **chat presentation**, not a restricted agent runtime. The model retains its original Shell (including Python), file, browser, memory and subagent tools according to pre-existing individual tool and connection settings. It may use them when appropriate without displaying raw commands, thinking traces and per-tool capsules. It should explain outcomes in ordinary language and never falsely claim work was performed.

Advanced UI reveals the original execution capsules, terminal entry points, diagnostic details and technical settings. Toggling it does NOT grant or revoke tools. Permission, user approval for destructive/write operations, Keychain credentials, per-connection controls and audit logging must still operate regardless of which UI is visible. The interactive `user_ask` card and meaningful errors must remain visible.

See [Marketplace design](PERSONAL_AGENT_MARKETPLACE.md) for the future unified MCP/Skills Connections implementation.

## Connections catalog / "Plugin Market"

Unify MCP connections, Skills, native capabilities under **Connections**, while retaining different installers and permission mechanics internally.

Each catalog entry contains: ID, name, one-line value proposition, provider and verified domain, type (`native`, `remote_mcp`, `skill`), manifest version, auth method, permission scopes, read/write classification, capabilities, update policy, source and audit status. A curated, vetted catalog is the default; "Add custom" is under Advanced.

Tap Connect:
1. Display data access and possible write actions before enabling.
2. For remote MCP: validate endpoint, OAuth metadata / PKCE flow when applicable, securely save tokens, discover capabilities, test connection, and show connected state.
3. For Skill: review source, permissions, dependencies and integrity before installing the manifest; never execute arbitrary unreviewed scripts because a card was tapped.
4. For native capabilities: request iOS permission only at first relevant use, with clear purpose.
5. Show Enabled/Needs permission/Error/Update states; disconnect and revoke correctly.

**One tap** means simple guided connection, not bypassed security or access to arbitrary user accounts without authorization. Personal Team build limitations (App Group, APNs, iCloud, WeatherKit, etc.) must be disclosed and guarded.

First catalog candidates: Apple Calendar, Reminders, on-device Living Memory, then Apple Weather (if entitled), ParkGo read-only journey context, and a small set of vetted remote MCP integrations. The first three are existing on-device capabilities, not external MCPs.

## UX/navigation

Default start = Chat + inline Today panel. Today is **content in chat**, not a modal accessed through Tools. Suggested navigation:
- Chat (main, Today highlights at top)
- Connections (catalog + installed)
- Settings (compact sections)
- Optional History/Inbox accessible from sidebar.

Move tools and console to Advanced, with an explicit warning about command execution. Do not delete history, files, credentials, old Skills/MCP settings, or established workspace state in migration. Preserve Dynamic Type, VoiceOver, iOS 16 compatibility and dark mode.

## Delivery sequence & acceptance criteria

### P0 — Make the chat personal (first shippable vertical slice)
- Personal Mode setting, default ON for a clean installation; migrate existing installations without silently reducing capabilities (explicit choice).
- Main chat hosts a native Today briefing card driven by existing deterministic facts.
- On user interaction, a consented `PersonalBriefingService` uses the selected LLM to explain/reprioritize a factual summary. Do not auto-send personal info unless opted in.
- Add structured `PersonalCard` envelope and a native renderer for agenda/insight/reminder; keep old `butler-card` compatible.
- Hide dev tools/think traces from main chat, while providing a way to inspect action history.
- End-to-end test: install -> grant Calendar -> see Today in chat -> opt in -> get an actual model-generated source-backed brief -> tap to continue chatting. No invented travel time.

### P1 — Safe personal actions and notifications
- Typed native action dispatcher, permission review and confirmation UX.
- Reminder completion / schedule change proposals gated by authorization.
- Priority, quiet hours, dedup, opt-in local notifications, exact source links.
- Test denied/revoked permissions, duplicate suppression, staleness and background restrictions.

### P2 — Connections store
- Curated catalog screen, install/enable/disable/disconnect; native + remote MCP + Skills adapters.
- Permission manifest, OAuth integration, Keychain storage and security review.
- Keep raw JSON import and server forms under Advanced only.
- Test offline, auth expiration, broken servers, tool schema refresh, malicious/untrusted manifests, capability revocation.

### P3 — Personalization + ParkGo + optional server
- Editable Living Memory with user-visible sources, contradictions, expiry and consent.
- ParkGo MCP/HTTP connector (read-only first): ETA/alerts/parking, source timestamps, freshness and cache policy. No fabricated journey recommendations.
- Optional VPS observer + APNs for true external proactive alerts; no continuous location tracking without explicit permission.

## Code map and suggested new seams

- New `PersonalContextAdapter`, `PersonalBriefingService`, `PersonalNotificationPolicy`: `src/ios/Agent/Personal/` **only if Xcode project file references are updated**; easier first step is adding files to the synchronized view group or amending pbxproj carefully.
- `src/ios/Views/ContentView/ButlerOnDevice.swift`: reuse factual models and rules; do not grow the already-large view. Extract services and card model.
- `src/ios/Views/Chat/AssistantBlockView.swift` / `Agent/MessageList/`: add typed native card block and separate approval/action channel.
- `src/ios/Agent/Chat/AIChatViewModel+SystemPrompt.swift`, `+ToolDefinitions.swift`, and dispatchers: consistent Personal/Advanced tool capability gate.
- `src/ios/Views/Settings/SettingsSheet.swift`: consolidate primary settings and route technical pages to Advanced.
- `src/ios/Views/MCP/MCPIntegrationsView.swift`, `src/ios/Views/Skills/SkillsManagementView.swift`: remain operational as underlying management panels; new Connections catalog calls their existing stores.
- `src/ios/Views/ContentView/ButlerLocalNotifications.swift`: expand only when the semantics and test coverage are ready.

Avoid adding more monolithic ViewBuilders: the recent Xcode builds hit Swift type-check timeouts in `ContentView` and `AIChatView`. Prefer small subviews / helpers with stable identity and careful state ownership.

## Release guardrails

- Never silently broaden calendar, location, health or memory sharing. Default sharing OFF; read permissions separated from actions.
- Never promise app-killed iOS background execution or network monitoring without server delivery.
- Remote model output is untrusted. Allowlisted card schema and actions, bounded strings, no generated arbitrary code/actions, no auto-run Shell from a UI card.
- Store minimal, user-visible durable facts and consent records; allow deletion, export, retention and expiry.
- Personal Team no-entitlement variant must launch without App Group. Add tests for iOS 16 availability and private app-sandbox fallback.
- Build gate: no compiler timeout, no runtime forced-unwrap crash, no loss of draft/selection while Today updates, no account data lost when switching modes.
- Preserve GPLv3 notices and source-distribution obligations of OpenMinis fork.

## Design references

- Open Intelligent UI: https://github.com/thesysdev/open-intelligent-ui (interactive structured UI **concept**, not a React renderer to embed blindly inside SwiftUI).
- OpenUI: https://github.com/thesysdev/openui (typed components and generative UI protocol ideas).
- Apple BackgroundTasks docs: https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app
- MCP authorization spec: https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization

**Branch scope:** the original Butler foundation remains unchanged; the V2 branch now contains a P0 implementation slice plus this evolving blueprint. Build and device tests are pending.
