//
//  ReminderDueDateParser.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.14
//

import Foundation

enum ReminderDueDateParser {
    private static let isoWithoutTimeZoneParseStrategy = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)T\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
        timeZone: .current,
        calendar: .current
    ).parseStrategy

    private static let spacedDateTimeParseStrategy = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
        timeZone: .current,
        calendar: .current
    ).parseStrategy

    static func parse(_ dueDateString: String?) -> Date? {
        guard let trimmed = dueDateString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        if let date = try? Date(trimmed, strategy: .iso8601) {
            return date
        }

        if let date = try? Date(trimmed, strategy: isoWithoutTimeZoneParseStrategy) {
            return date
        }

        if let date = try? Date(trimmed, strategy: spacedDateTimeParseStrategy) {
            return date
        }

        if trimmed.count == 10 {
            let parts = trimmed.split(separator: "-")
            guard parts.count == 3,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]),
                  let day = Int(parts[2]) else {
                return nil
            }

            var components = DateComponents()
            components.calendar = .current
            components.timeZone = .current
            components.year = year
            components.month = month
            components.day = day
            components.hour = 9
            return components.date
        }

        return nil
    }

    static func dueDateComponents(from dueDateString: String?) -> DateComponents? {
        guard let dueDate = parse(dueDateString) else {
            return nil
        }

        var components = Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
            from: dueDate
        )
        components.calendar = .current
        components.timeZone = .current
        return components
    }

    static func displayText(dueDateString: String?, rawDueDatePhrase: String?) -> String? {
        if let dueDate = parse(dueDateString) {
            return dueDate.formatted(date: .abbreviated, time: .shortened)
        }

        guard let rawDueDatePhrase,
              !rawDueDatePhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return rawDueDatePhrase
    }

    static func splitEmbeddedDuePhrase(
        from title: String,
        now: Date,
        timeZone: TimeZone
    ) -> (cleanTitle: String, rawDueDatePhrase: String?, dueDateString: String?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            return ("", nil, nil)
        }

        if let match = match(
            pattern: #"(?i)^(.*?)(?:\s+on\s+(?:a\s+)?)((?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+at\s+\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?))?)\.?$"#,
            in: trimmedTitle
        ) {
            let cleanTitle = cleanedActionTitle(match.prefix)
            let rawPhrase = cleanedDuePhrase(match.suffix)
            return (
                cleanTitle,
                rawPhrase,
                resolvedDueDateString(from: rawPhrase, now: now, timeZone: timeZone)
            )
        }

        if let match = match(
            pattern: #"(?i)^(.*?)(?:\s+)(this\s+(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+at\s+\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?))?)\.?$"#,
            in: trimmedTitle
        ) {
            let cleanTitle = cleanedActionTitle(match.prefix)
            let rawPhrase = cleanedDuePhrase(match.suffix)
            return (
                cleanTitle,
                rawPhrase,
                resolvedDueDateString(from: rawPhrase, now: now, timeZone: timeZone)
            )
        }

        return (trimmedTitle, nil, nil)
    }

    private static func resolvedDueDateString(
        from rawPhrase: String?,
        now: Date,
        timeZone: TimeZone
    ) -> String? {
        guard let rawPhrase else { return nil }

        let normalized = rawPhrase
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let weekdays: [String: Int] = [
            "sunday": 1,
            "monday": 2,
            "tuesday": 3,
            "wednesday": 4,
            "thursday": 5,
            "friday": 6,
            "saturday": 7
        ]

        guard let weekdayEntry = weekdays.first(where: { normalized.contains($0.key) }) else {
            return nil
        }

        let calendar = Calendar(identifier: .gregorian)
        var searchCalendar = calendar
        searchCalendar.timeZone = timeZone

        let timePattern = /(\d{1,2})(?::(\d{2}))?\s*(am|pm)/
        let timeMatch = normalized.firstMatch(of: timePattern)
        let hourValue = Int(timeMatch?.output.1 ?? "")
        let minuteValue = Int(timeMatch?.output.2 ?? "") ?? 0
        let meridiem = timeMatch?.output.3

        var components = DateComponents()
        components.weekday = weekdayEntry.value
        components.hour = 9
        components.minute = 0
        components.second = 0
        components.timeZone = timeZone

        if let hourValue {
            components.hour = convertedHour(hourValue, meridiem: meridiem)
            components.minute = minuteValue
        }

        guard let resolvedDate = searchCalendar.nextDate(
            after: now.addingTimeInterval(-1),
            matching: components,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            repeatedTimePolicy: .first,
            direction: .forward
        ) else {
            return nil
        }

        return resolvedDate.ISO8601Format()
    }

    private static func convertedHour(_ hour: Int, meridiem: Substring?) -> Int {
        guard let meridiem else { return hour }
        switch meridiem {
        case "pm" where hour < 12:
            return hour + 12
        case "am" where hour == 12:
            return 0
        default:
            return hour
        }
    }

    private static func cleanedActionTitle(_ value: Substring) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func cleanedDuePhrase(_ value: Substring) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func match(pattern: String, in text: String) -> (prefix: Substring, suffix: Substring)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let result = regex.firstMatch(in: text, options: [], range: range),
              result.numberOfRanges >= 3,
              let prefixRange = Range(result.range(at: 1), in: text),
              let suffixRange = Range(result.range(at: 2), in: text) else {
            return nil
        }

        return (text[prefixRange], text[suffixRange])
    }
}
