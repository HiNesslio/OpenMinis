import Foundation
import XCTest
@testable import Minis

final class ButlerOnDeviceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func event(
        _ id: String, start: TimeInterval, duration: TimeInterval = 1_800,
        location: String? = nil, allDay: Bool = false
    ) -> ButlerAgendaItem {
        ButlerAgendaItem(
            id: id, title: "Meeting \(id)",
            start: now.addingTimeInterval(start),
            end: now.addingTimeInterval(start + duration),
            location: location, isAllDay: allDay
        )
    }

    func testUpcomingLocationTriggersCautiousDepartureCheck() {
        let insights = ButlerDecisionEngine.evaluate(
            now: now, events: [event("one", start: 3_600, location: "Office")], tasks: []
        )
        XCTAssertEqual(insights.map(\.kind), [.nextAppointment])
        XCTAssertTrue(insights[0].detail.contains("實際路況"))
        XCTAssertFalse(insights[0].detail.contains("分鐘車程"))
    }

    func testNoLocationDoesNotInventTransitTime() {
        let insights = ButlerDecisionEngine.evaluate(
            now: now, events: [event("one", start: 3_600)], tasks: []
        )
        XCTAssertTrue(insights.isEmpty)
    }

    func testAllDayEventIgnoredForDeparture() {
        let insights = ButlerDecisionEngine.evaluate(
            now: now, events: [event("one", start: 3_600, location: "Office", allDay: true)], tasks: []
        )
        XCTAssertTrue(insights.isEmpty)
    }

    func testShortGapDetected() {
        let events = [
            event("one", start: 120 * 60, duration: 60 * 60),
            event("two", start: 190 * 60, duration: 60 * 60)
        ]
        let insights = ButlerDecisionEngine.evaluate(now: now, events: events, tasks: [])
        XCTAssertEqual(insights.filter { $0.kind == .tightSchedule }.count, 1)
    }

    func testOverlappingEventsSurfaceConflict() {
        let events = [
            event("one", start: 120 * 60, duration: 60 * 60),
            event("two", start: 150 * 60, duration: 60 * 60)
        ]
        let insights = ButlerDecisionEngine.evaluate(now: now, events: events, tasks: [])
        XCTAssertTrue(insights.contains(where: { $0.title == "行程時間重疊" }))
    }

    func testBriefingDoesNotClaimMissingPermissionsAreEmptySchedules() {
        let briefing = ButlerBriefingComposer.compose(
            now: now, events: [], tasks: [],
            hasCalendarAccess: false, hasReminderAccess: false
        )
        XCTAssertTrue(briefing.summary.contains("連接"))
        XCTAssertFalse(briefing.summary.contains("今日還有 0 項行程"))
    }

    func testOldOverdueReminderNotResurfaced() {
        let task = ButlerTaskItem(id: "old", title: "old", due: now.addingTimeInterval(-9 * 86400))
        XCTAssertTrue(ButlerDecisionEngine.evaluate(now: now, events: [], tasks: [task]).isEmpty)
    }

    func testLocalNotificationPlanUsesRealStartMinus30Minutes() {
        let e = event("one", start: 2 * 3600)
        let plans = ButlerNotificationPlanner.plans(events: [e], now: now)
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(plans[0].fireAt, e.start.addingTimeInterval(-1800))
        XCTAssertEqual(plans[0].identifier, "butler.upcoming.one")
    }

    func testTooSoonAndAllDayNeverSchedule() {
        let plans = ButlerNotificationPlanner.plans(
            events: [event("soon", start: 10 * 60), event("all", start: 2 * 3600, allDay: true)],
            now: now
        )
        XCTAssertTrue(plans.isEmpty)
    }

    func testCardParsesBoundedStandaloneJSON() {
        let json = #"{"version":1,"kind":"agenda","title":"Today","summary":"Two events","items":[{"title":"Meeting","detail":"Office","time":"09:00"}]}"#
        let fence = String(repeating: "\u{0060}", count: 3)
        let markdown = fence + "butler-card\n" + json + "\n" + fence
        let card = ButlerIntelligentCardParser.parse(markdown)
        XCTAssertEqual(card?.kind, "agenda")
        XCTAssertEqual(card?.items.first?.time, "09:00")
    }

    func testButlerStorageRootSupportsAppGroupAndPersonalTeam() {
        let fm = FileManager.default
        let base = AIChatViewModel.minisStorageContainerRoot
        if let appGroup = fm.containerURL(
            forSecurityApplicationGroupIdentifier: SharedContainerStore.appGroupID
        ) {
            XCTAssertEqual(base.standardizedFileURL, appGroup.standardizedFileURL)
        } else {
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
            XCTAssertEqual(
                base.standardizedFileURL,
                appSupport.appendingPathComponent("MinisPersonalDev", isDirectory: true).standardizedFileURL
            )
        }
        // Metadata, including MCP credentials, must never be under the
        // FileProvider-visible memory/skills/shared root.
        let exposed = AIChatViewModel.minisAppGroupRoot
        let config = AIChatViewModel.minisConfigRoot
        XCTAssertEqual(exposed.deletingLastPathComponent(), base)
        XCTAssertEqual(config.deletingLastPathComponent(), base)
        XCTAssertFalse(config.path.hasPrefix(exposed.path + "/"))
    }

    func testAIBriefingRejectsUnknownPriorityReferences() {
        let json = #"{"headline":"今日重點","summary":"請查看已確認的行程","priorityInsightIds":["I8"]}"#
        XCTAssertNil(ButlerAIBriefingService.parseValidatedResponse(
            json, allowedInsightIds: ["I0", "I1"]
        ))
    }

    func testAIBriefingAllowsSourceBoundedPriorities() {
        let json = #"{"headline":"有一項安排","summary":"請確認下一個已知行程","priorityInsightIds":["I0"]}"#
        let analysis = ButlerAIBriefingService.parseValidatedResponse(
            json, allowedInsightIds: ["I0"]
        )
        XCTAssertEqual(analysis?.priorityInsightIds, ["I0"])
        XCTAssertEqual(analysis?.headline, "有一項安排")
    }

    func testAIBriefingRejectsOverlongOrNonJSONResponses() throws {
        let payload: [String: Any] = [
            "headline": "今日",
            "summary": String(repeating: "長", count: 241),
            "priorityInsightIds": [String]()
        ]
        let encoded = try JSONSerialization.data(withJSONObject: payload)
        let response = String(decoding: encoded, as: UTF8.self)
        XCTAssertNil(ButlerAIBriefingService.parseValidatedResponse(
            response, allowedInsightIds: []
        ))
        XCTAssertNil(ButlerAIBriefingService.parseValidatedResponse(
            "The answer is: " + response, allowedInsightIds: []
        ))
    }

    func testCardFailsClosedOnUnknownTypeOrArbitraryText() {
        let json = #"{"version":1,"kind":"execute","title":"Run","items":[]}"#
        let fence = String(repeating: "\u{0060}", count: 3)
        XCTAssertNil(ButlerIntelligentCardParser.parse(fence + "butler-card\n" + json + "\n" + fence))
        XCTAssertNil(ButlerIntelligentCardParser.parse("Hello\n" + fence + "butler-card\n" + json + "\n" + fence))
        XCTAssertNil(ButlerIntelligentCardParser.parse(String(repeating: "x", count: 16_001)))
    }
}
