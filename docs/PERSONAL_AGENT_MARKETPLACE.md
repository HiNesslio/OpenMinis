# Personal Agent — Connections / Plugin Marketplace Plan

Status: architectural proposal, **not an implemented Marketplace**. Research verified 2026-11-24.

## Product decision

A "Plugin" is one customer-visible connection card; internally it can be one of:
- Native adapter: Apple Calendar / Reminders / local Living Memory (permissions only).
- Remote MCP server: an HTTPS Streamable HTTP endpoint, optionally with OAuth.
- Skill: version-pinned skill instructions / resources, potentially scripts which must be reviewed before execution.
- Curated integration gateway: e.g., Composio or Arcade for hosted per-user OAuth and tool dispatch.

The primary UI uses customer outcomes: "Manage my calendar", "Connect Notion", "Summarize a PDF" rather than technical names or stdio JSON. Power users can still add custom MCPs or raw Skills under Advanced.

**The model retains all enabled Shell, Python, file and browser capabilities. Personal Mode only hides technical output in conversation; this MUST NOT turn off authorization checks, destructive-action review, logging, or user-facing result summaries.**

## Build on existing OpenMinis implementation

The fork already has:
- `MCPStore.shared.add(_ server: MCPServerConfig)` / `toggle(id:)` / `delete(id:)` in `src/ios/Agent/Session/MCPStore.swift`. `MCPServerConfig` handles remote HTTP URL + optional OAuth config and STDIO (command + args) for Advanced use.
- `MCPOAuthController` stores secrets in Keychain; `MCPFormSheet` already presents authorization.
- `SkillStore.shared.preflightGitHubImport(urlString:)`, `commitGitHubImport(urlString:content:)` and `importFromGitHub(urlString:)` in `src/ios/Agent/Session/SkillStore.swift`. The preflight can validate a skill before import; sibling asset import may continue after initial Skill import and should report partial outcomes in marketplace UI.
- Existing `MCPIntegrationsView` and `SkillsManagementView` remain functional under Advanced. New catalog should call their stores, **not duplicate credential or install logic**.

## Source comparison

| Source | For | Integration | Limitation |
|---|---|---|---|
| Official MCP Registry | Discovery of remote MCP servers | `GET https://registry.modelcontextprotocol.io/v0.1/servers?search=...&version=latest` and detail by name | Registry is metadata, not OAuth/token storage or execution; public listings are not equivalent to safety approval |
| modelcontextprotocol/swift-sdk | Swift native remote MCP client with HTTP and OAuth | Existing OpenMinis MCP backend may already cover needs; evaluate before introducing a second runtime | Integration/testing required; iOS 16+ supported |
| Skills Directory (`skills.sh`) | Skills discovery/preview and security audit metadata | Search / curated / detail endpoints documented under `/api/v1/skills/` | Documented API requires Bearer Vercel OIDC token: **never embed it in iOS app**; use separately authorized cached server-side integration or GitHub-first curated index |
| Composio | Rapid third-party app integrations, managed per-user OAuth | SDK/session MCP endpoint, use externally owned connection identity | Vendor-managed authentication/data path, pricing, privacy and service dependency; choose only with informed opt-in |
| Arcade | Managed auth, hosted connectors and tools | SDK/API/MCP gateway | Same third-party trust/vendor cost concerns |
| Smithery | Public directory only | Link directly to vendor's MCP URL after verification | Smithery Connect/API/SDK/Proxy **shut down 2026-10-31**. Do not build on its deprecated identity layer |

Sources:
- https://github.com/modelcontextprotocol/registry
- https://github.com/modelcontextprotocol/swift-sdk
- https://www.skills.sh/docs/api
- https://docs.composio.dev/docs/composio-connect
- https://docs.arcade.dev/en/get-started/about-arcade
- https://smithery.ai/future

## Recommended architecture

```
SwiftUI Connections home
   |
   +-- Curated catalog (bundled JSON; safe offline)
   +-- Search API (read-only; cached)
   |    +-- Official MCP Registry metadata
   |    +-- Skills.sh / GitHub source metadata
   |
   +-- Card details: source + scopes + capabilities + verification + version
   |
   +-- ConnectAction
         +-- native -> EventKit permission request
         +-- remote_mcp -> verify HTTPS URL + supported transport -> store
         |                   -> OAuth browser login -> token Keychain
         |                   -> initialize / list tools -> enabled
         +-- skill -> fetch/pin digest -> inspect contents + assets
                       -> install to SkillStore -> enabled
         +-- gateway -> user-authorized vendor identity -> runtime tools
```

Never let registry metadata issue arbitrary shell commands on an iPhone, even though Shell is available to the agent for actual tasks. HTTP MCP is default; STDIO (npm, Python, npx) under an explicit Advanced flow with dependencies, package provenance and execution consent.

## Catalog model

```json
{
  "id": "io.vendor/example",
  "kind": "remote_mcp",
  "display_name": "Example Service",
  "description": "Manage your example tasks",
  "source_registry": "official_mcp",
  "vendor_name": "Example",
  "verified_website": "https://example.com",
  "install": {
    "transport": "streamable_http",
    "endpoint": "https://mcp.example.com/mcp",
    "oauth": "discovery"
  },
  "permissions": [
    { "scope": "read_tasks", "risk": "read" },
    { "scope": "write_tasks", "risk": "write_confirmation" }
  ],
  "version": "1.0.0",
  "install_state": "not_installed"
}
```

All of this is a *shape example*, not a real vendor or working server. Do not trust the `verified_website` field purely because it appears in a remote catalog; verify with the service operator's official listing/domain.

## UX

- "探索" view: suggested connections / calendars & work / travel / productivity / installed.
- Compact card: recognizable icon, clear one-line user benefit, trust indicator (only with actual verification), Connect/Connected/Needs authorization.
- Details: "AI 可以讀取／修改什麼", vendor, privacy link, last verified/update, linked account, "Disconnect" and access log. Technical endpoint in Advanced.
- Connect: display scope disclosure, complete `ASWebAuthenticationSession` with PKCE or an approved managed gateway, store token in Keychain, test MCP initialize/tools/list, then show Connected.
- Install Skill: show source, hash, supporting files/scripts and security audit information; warn scripts may run via agent Shell after enabling; only install from a source/revision that was previewed. Re-evaluate risky updates.
- For destructive writes/send/payments, continue prompting for explicit user confirmation even though technical tool chips are hidden. Retain meaningful activity record accessible from account/card details.

## Phase sequence

P0 (MVP): hardcoded reviewed catalog of 6–10 entries + unified Connections home + already-connected status + one-tap enable for native and known unauthenticated remote MCP servers; GitHub Skill install via existing SkillStore with preview.

P1: official Registry search/filter/details + OAuth/PKCE connection + per-server permissions + reconnect/revoke state; maintain stable server IDs and avoid overwriting existing MCP configurations.

P2: Skills catalog backend/proxy or GitHub-curated list; secure revision/hash pinning; audit metadata + automatic update checks with approval. No universal auto-install of unreviewed arbitrary scripts.

P3: opt-in hosted gateway (Composio/Arcade, or own VPS) for popular integrations requiring managed user authorization; optional ParkGo read-only MCP.

## Technical cautions

- `skills.sh` API is documented with Bearer Vercel OIDC credentials. A public client cannot safely store service tokens. A small cache on an existing VPS is appropriate if authorized service-to-service access is configured. For a personal-only app, a bundled curated list + GitHub public content fetch is sufficient initially.
- Native iOS integrations may not need MCP and require platform entitlements; do not show misleading "Connect" success if permissions are denied.
- Permission scope and tool-level policy must be enforced at execution, independent of rendering. Disable/disconnect should remove tools from future schemas and reject in-flight calls when permissions are revoked.
- Always show end-user confirmation for sending messages, modifying calendar tasks, deleting files, writing to remote systems or making purchases.
- App Store / distribution may impose additional restrictions on downloaded or executed code. Keep Skills as data/instructions by default; handle executable scripts conservatively and seek platform compliance review before release.
- Use legitimate server/operator verified endpoints rather than arbitrary community entries by default. Cached catalog must fail closed when the endpoint or auth method changes unexpectedly.
