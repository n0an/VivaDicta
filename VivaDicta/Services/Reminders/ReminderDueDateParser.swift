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
}
