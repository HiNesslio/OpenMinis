//
//  ConnectionsMarketplaceView.swift
//  Personal Agent V2: curated, permission-aware native Connections catalog.
//
//  Lives in the existing Xcode file-system-synchronized ContentView group.
//  The catalog is presentation only; MCPStore and SkillStore remain the
//  authoritative installers. No remotely supplied command is auto-executed.
//

import EventKit
import SwiftUI

enum MarketplaceKind: String, CaseIterable, Identifiable {
    case native = "原生"
    case mcp = "連接服務"
    case skill = "技能"

    var id: String { rawValue }
}

struct MarketplaceEntry: Identifiable {
    let id: String
    let title: String
    let description: String
    let provider: String
    let symbol: String
    let kind: MarketplaceKind
    let permissionExplanation: String
    var endpoint: String? = nil
    var skillURL: String? = nil

    /// Reviewed starter catalog, not a remotely executable public registry.
    /// MCP URLs are the service owners' documented Streamable HTTP endpoints.
    /// Skill URLs refer to published source SKILL.md files for review.
    static let featured: [MarketplaceEntry] = [
        .init(id: "native-calendar", title: "Apple 日曆",
              description: "整理行程與時間衝突", provider: "Apple",
              symbol: "calendar", kind: .native,
              permissionExplanation: "讀取經你授權的日曆行程。AI Briefing 另需明確同意才會把行程摘要發送至模型。"),
        .init(id: "native-reminders", title: "提醒事項",
              description: "整理待辦與到期事項", provider: "Apple",
              symbol: "checklist", kind: .native,
              permissionExplanation: "讀取經你授權的提醒事項。修改待辦仍應由你確認。"),
        .init(id: "native-memory", title: "個人記憶",
              description: "管理已保存的個人偏好", provider: "本機",
              symbol: "brain.head.profile", kind: .native,
              permissionExplanation: "記憶資料由 OpenMinis 原有本機儲存管理；進入管理頁可查看與刪除。"),
        .init(id: "notion", title: "Notion",
              description: "搜尋及管理 Notion 工作空間", provider: "Notion",
              symbol: "doc.text", kind: .mcp,
              permissionExplanation: "連接會開啟 Notion 官方登入與授權。MCP 工具可能支援讀取及修改工作空間；請檢查帳戶授權範圍。",
              endpoint: "https://mcp.notion.com/mcp"),
        .init(id: "linear", title: "Linear",
              description: "查詢 Issue、Project 及規劃", provider: "Linear",
              symbol: "square.stack.3d.up", kind: .mcp,
              permissionExplanation: "透過 Linear 官方 MCP 連接帳戶。預設 Endpoint 支援讀取及寫入，重要修改仍需確認。",
              endpoint: "https://mcp.linear.app/mcp"),
        .init(id: "sentry", title: "Sentry",
              description: "查看錯誤與問題脈絡", provider: "Sentry",
              symbol: "waveform.path.ecg", kind: .mcp,
              permissionExplanation: "使用 Sentry 官方遠端 MCP。連接前會顯示授權頁；工具可能讀取專案與錯誤資料。",
              endpoint: "https://mcp.sentry.dev/mcp"),
        .init(id: "skill-pdf", title: "PDF 文件",
              description: "解析及處理 PDF", provider: "Anthropic Skills",
              symbol: "doc.richtext", kind: .skill,
              permissionExplanation: "將安裝公開 GitHub Skill 指令與所需資源；部分操作可能依賴本機 Python 或其他套件。",
              skillURL: "https://github.com/anthropics/skills/blob/main/skills/pdf/SKILL.md"),
        .init(id: "skill-docx", title: "Word 文件",
              description: "建立及處理 DOCX 文件", provider: "Anthropic Skills",
              symbol: "doc.text.image", kind: .skill,
              permissionExplanation: "下載前可預覽 SKILL.md；部分文件處理操作可能需要額外 Python 套件。",
              skillURL: "https://github.com/anthropics/skills/blob/main/skills/docx/SKILL.md"),
        .init(id: "skill-xlsx", title: "試算表",
              description: "分析及處理 XLSX 資料", provider: "Anthropic Skills",
              symbol: "tablecells", kind: .skill,
              permissionExplanation: "下載前可預覽 SKILL.md；實際操作可能需要 Python 與試算表處理依賴。",
              skillURL: "https://github.com/anthropics/skills/blob/main/skills/xlsx/SKILL.md")
    ]

    var sourceURL: URL? {
        URL(string: endpoint ?? skillURL ?? "")
    }
}

private enum MarketplaceFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case installed = "已安裝"
    case mcp = "MCP"
    case skills = "技能"

    var id: String { rawValue }
}

/// A small, native catalog screen. It never interprets remote registry
/// metadata as permission to execute commands or install arbitrary packages.
struct ConnectionsMarketplaceView: View {
    @ObservedObject private var mcpStore = MCPStore.shared
    @ObservedObject private var skillStore = SkillStore.shared
    @State private var searchText = ""
    @State private var filter: MarketplaceFilter = .all

    private var visibleEntries: [MarketplaceEntry] {
        MarketplaceEntry.featured.filter { entry in
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || (entry.title + " " + entry.description + " " + entry.provider)
                    .localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .installed: matchesFilter = isInstalled(entry)
            case .mcp: matchesFilter = entry.kind == .mcp
            case .skills: matchesFilter = entry.kind == .skill
            }
            return matchesSearch && matchesFilter
        }
    }

    private func isInstalled(_ entry: MarketplaceEntry) -> Bool {
        switch entry.kind {
        case .native:
            return true // available as built-in capability; permission is separate
        case .mcp:
            return mcpStore.servers.contains { $0.id == entry.id && $0.url == entry.endpoint }
        case .skill:
            return skillStore.skills.contains { $0.sourceURL == entry.skillURL }
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 7) {
                    Text("連接你日常使用的服務")
                        .font(.headline)
                    Text("探索能力、檢查授權，一按加入你的 Personal Agent。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Picker("類型", selection: $filter) {
                    ForEach(MarketplaceFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            Section {
                if visibleEntries.isEmpty {
                    Text("沒有符合條件的連接")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleEntries) { entry in
                    NavigationLink {
                        MarketplaceConnectionDetail(entry: entry)
                    } label: {
                        MarketplaceCatalogRow(entry: entry, isInstalled: isInstalled(entry))
                    }
                }
            } header: {
                Text(filter == .installed ? "已安裝的精選連接" : "精選連接")
            }

            Section {
                NavigationLink {
                    MCPIntegrationsView()
                } label: {
                    Label("已加入的 MCP 服務", systemImage: "point.3.connected.trianglepath.dotted")
                }
                NavigationLink {
                    SkillsManagementView()
                } label: {
                    Label("管理已安裝技能", systemImage: "square.stack")
                }
            } header: {
                Text("更多管理")
            } footer: {
                Text("目錄只提供已知來源。安裝不代表已授權或成功連線；第三方服務需要完成登入及連線驗證。")
            }
        }
        .navigationTitle("探索連接")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜尋服務與技能")
        .onAppear {
            mcpStore.load()
            skillStore.reload()
        }
    }
}

private struct MarketplaceCatalogRow: View {
    let entry: MarketplaceEntry
    let isInstalled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 42, height: 42)
                .background(Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).font(.subheadline.weight(.semibold))
                Text(entry.description)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if entry.kind == .native {
                Text("原生")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("已加入")
            } else {
                Text(entry.kind.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

/// Models all three connection types but delegates implementation to existing
/// OS consent, MCPStore, MCPFormSheet, and SkillStore components.
struct MarketplaceConnectionDetail: View {
    let entry: MarketplaceEntry

    @ObservedObject private var mcpStore = MCPStore.shared
    @ObservedObject private var skillStore = SkillStore.shared
    @StateObject private var today = ButlerTodayModel()

    @State private var configuringMCP: MCPServerConfig?
    @State private var skillPreview: MarketplaceSkillPreview?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var existingMCP: MCPServerConfig? {
        mcpStore.servers.first(where: { $0.id == entry.id })
    }

    private var installedSkill: Skill? {
        skillStore.skills.first(where: { $0.sourceURL == entry.skillURL })
    }

    private var nativeAuthorizationDescription: String {
        switch entry.id {
        case "native-calendar": return today.calendarAuthorized ? "已授權讀取" : "尚未授權"
        case "native-reminders": return today.remindersAuthorized ? "已授權讀取" : "尚未授權"
        default: return "本機功能"
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: entry.symbol)
                        .font(.system(size: 28, weight: .regular))
                        .frame(width: 58, height: 58)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 16))
                    Text(entry.title).font(.title2.weight(.semibold))
                    Text(entry.description)
                        .font(.body).foregroundStyle(.secondary)
                    Text("提供者：\(entry.provider)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section("資料與權限") {
                Text(entry.permissionExplanation)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = entry.sourceURL {
                    Link("查看官方來源", destination: url)
                }
            }

            Section("連接狀態") {
                connectionControls
                if let successMessage {
                    Label(successMessage, systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if entry.kind == .native { await today.refresh() }
        }
        .sheet(item: $configuringMCP) { server in
            MCPFormSheet(server: server, prefersBrowserSignIn: true)
        }
        .sheet(item: $skillPreview) { preview in
            MarketplaceSkillReviewSheet(preview: preview) { installed in
                successMessage = "已安裝「\(installed)」"
            }
        }
        .alert("連接未完成", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var connectionControls: some View {
        switch entry.kind {
        case .native: nativeControls
        case .mcp: mcpControls
        case .skill: skillControls
        }
    }

    @ViewBuilder
    private var nativeControls: some View {
        if entry.id == "native-memory" {
            NavigationLink {
                MemoryManagementView()
            } label: {
                Label("管理個人記憶", systemImage: "brain.head.profile")
            }
        } else {
            HStack {
                Text(nativeAuthorizationDescription)
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.id == "native-calendar" {
                    Button(today.calendarAuthorized ? "重新整理" : "授權") {
                        Task { await today.requestCalendar() }
                    }
                } else {
                    Button(today.remindersAuthorized ? "重新整理" : "授權") {
                        Task { await today.requestReminders() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mcpControls: some View {
        if let existing = existingMCP, existing.url != entry.endpoint {
            Text("此服務名稱已被另一個 MCP 設定使用。請先到進階 MCP 管理頁檢查，以免覆蓋原有連接。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if let existing = existingMCP {
            let authorized = MCPOAuthController.isAuthorized(server: existing.id)
            Label(
                authorized
                    ? (existing.enabled ? "已授權並啟用" : "已授權，尚未啟用")
                    : "已加入設定，等待帳戶授權",
                systemImage: authorized ? "checkmark.shield" : "person.crop.circle.badge.questionmark"
            )
            .font(.subheadline)
            Button(authorized ? "管理連接" : "繼續連接") {
                configuringMCP = existing
            }
            if authorized && !existing.enabled {
                Button("啟用服務") { mcpStore.toggle(id: existing.id) }
            }
            if existing.enabled {
                Button("停用服務") { mcpStore.toggle(id: existing.id) }
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("加入後會開啟帳戶授權。登入完成前，服務不會提供任何工具。")
                .font(.caption).foregroundStyle(.secondary)
            Button("加入並連接") { stageMCPConnection() }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var skillControls: some View {
        if let skill = installedSkill {
            Label(skill.isEnabled ? "已安裝並啟用" : "已安裝，已停用",
                  systemImage: "checkmark.circle")
            Button(skill.isEnabled ? "停用技能" : "啟用技能") {
                skillStore.setEnabled(skill.id, enabled: !skill.isEnabled)
            }
        } else {
            Text("安裝前會下載來源 SKILL.md，讓你檢查內容。外部腳本不會在安裝時自動執行。")
                .font(.caption).foregroundStyle(.secondary)
            Button {
                Task { await prepareSkill() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("預覽並安裝")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
    }

    private func stageMCPConnection() {
        guard let endpoint = entry.endpoint,
              let parsed = URL(string: endpoint),
              parsed.scheme == "https",
              let host = parsed.host,
              !host.isEmpty else {
            errorMessage = "此服務沒有有效的 HTTPS 連接地址。"
            return
        }
        // Never silently overwrite a manually configured server on name
        // collision, even if it arrived while this detail screen was open.
        if let existing = existingMCP {
            if existing.url == endpoint {
                configuringMCP = existing
            } else {
                errorMessage = "已有相同名稱的自訂服務。請先檢查 MCP 管理頁。"
            }
            return
        }
        var config = MCPServerConfig(id: entry.id, enabled: false)
        config.url = endpoint
        config.note = "\(entry.provider) 官方遠端 MCP（由 Connections 目錄加入）"
        mcpStore.add(config)
        configuringMCP = config
    }

    @MainActor
    private func prepareSkill() async {
        guard let url = entry.skillURL else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await skillStore.preflightGitHubImport(urlString: url)
            if let conflict = skillStore.skills.first(where: { $0.id == result.id }),
               conflict.sourceURL != url {
                errorMessage = "已有同名技能「\(conflict.name)」。為避免覆蓋，請先到技能管理頁檢查。"
                return
            }
            skillPreview = MarketplaceSkillPreview(
                id: result.id, name: result.name, content: result.content,
                sourceURL: url
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct MarketplaceSkillPreview: Identifiable {
    let id: String
    let name: String
    let content: String
    let sourceURL: String
}

/// User confirms the actual downloaded instructions, not just a marketing card.
private struct MarketplaceSkillReviewSheet: View {
    let preview: MarketplaceSkillPreview
    let onInstalled: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var installing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(preview.name)
                        .font(.title3.weight(.semibold))
                    Text("以下為來源 SKILL.md 內容預覽。技能可能引用其他腳本或依賴；安裝後請按需要審核。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(preview.content)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .navigationTitle("檢查技能內容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await install() }
                } label: {
                    if installing { ProgressView() }
                    else { Text("確認安裝") }
                }
                .disabled(installing)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
            }
            .alert("安裝失敗", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @MainActor
    private func install() async {
        guard !installing else { return }
        installing = true
        defer { installing = false }
        do {
            // Guard against stale preview + an ID collision since opening the
            // sheet. This import can fetch sibling resources asynchronously.
            if let conflict = SkillStore.shared.skills.first(where: { $0.id == preview.id }),
               conflict.sourceURL != preview.sourceURL {
                errorMessage = "已有同名但不同來源的技能。"
                return
            }
            let installed = try await SkillStore.shared.commitGitHubImport(
                urlString: preview.sourceURL, content: preview.content
            )
            onInstalled(installed.name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
