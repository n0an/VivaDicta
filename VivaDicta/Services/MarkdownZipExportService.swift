//
//  MarkdownZipExportService.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import Foundation

enum MarkdownZipExportService {
    nonisolated static func createArchive(from items: [MarkdownExportItem], now: Date = .now) throws -> URL {
        let directoryURL = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let archiveURL = directoryURL.appending(path: archiveFilename(for: items.count, now: now))
        let entries = items.map { ZipArchiveEntry(filename: $0.filename, data: Data($0.text.utf8)) }

        try ZipArchiveWriter.write(entries: entries, to: archiveURL)
        return archiveURL
    }

    nonisolated static func cleanupArchive(at archiveURL: URL) {
        try? FileManager.default.removeItem(at: archiveURL)

        let parentDirectory = archiveURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parentDirectory)
    }

    nonisolated private static func archiveFilename(for count: Int, now: Date) -> String {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )

        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let noteLabel = count == 1 ? "note" : "notes"

        return "VivaDicta-\(count)-\(noteLabel)-\(year)-\(twoDigit(month))-\(twoDigit(day))_\(twoDigit(hour))\(twoDigit(minute))\(twoDigit(second)).zip"
    }

    nonisolated private static func twoDigit(_ value: Int) -> String {
        if value < 10 {
            return "0\(value)"
        }

        return "\(value)"
    }
}

struct ZipArchiveEntry: Sendable {
    let filename: String
    let data: Data
}

enum ZipArchiveWriter {
    nonisolated static func write(entries: [ZipArchiveEntry], to url: URL) throws {
        let dosDateTime = dosDateTime(from: .now)
        var archiveData = Data()
        var centralDirectory = Data()
        var localHeaderOffset: UInt32 = 0

        for entry in entries {
            let filenameData = Data(entry.filename.utf8)
            let crc32 = CRC32.checksum(for: entry.data)
            let uncompressedSize = try uint32(entry.data.count)
            let filenameLength = try uint16(filenameData.count)

            archiveData.append(littleEndian: UInt32(0x04034B50))
            archiveData.append(littleEndian: UInt16(20))
            archiveData.append(littleEndian: UInt16(0))
            archiveData.append(littleEndian: UInt16(0))
            archiveData.append(littleEndian: dosDateTime.time)
            archiveData.append(littleEndian: dosDateTime.date)
            archiveData.append(littleEndian: crc32)
            archiveData.append(littleEndian: uncompressedSize)
            archiveData.append(littleEndian: uncompressedSize)
            archiveData.append(littleEndian: filenameLength)
            archiveData.append(littleEndian: UInt16(0))
            archiveData.append(filenameData)
            archiveData.append(entry.data)

            centralDirectory.append(littleEndian: UInt32(0x02014B50))
            centralDirectory.append(littleEndian: UInt16(20))
            centralDirectory.append(littleEndian: UInt16(20))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: dosDateTime.time)
            centralDirectory.append(littleEndian: dosDateTime.date)
            centralDirectory.append(littleEndian: crc32)
            centralDirectory.append(littleEndian: uncompressedSize)
            centralDirectory.append(littleEndian: uncompressedSize)
            centralDirectory.append(littleEndian: filenameLength)
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt32(0))
            centralDirectory.append(littleEndian: localHeaderOffset)
            centralDirectory.append(filenameData)

            localHeaderOffset = try uint32(archiveData.count)
        }

        let centralDirectoryOffset = try uint32(archiveData.count)
        archiveData.append(centralDirectory)

        let entryCount = try uint16(entries.count)
        let centralDirectorySize = try uint32(centralDirectory.count)

        archiveData.append(littleEndian: UInt32(0x06054B50))
        archiveData.append(littleEndian: UInt16(0))
        archiveData.append(littleEndian: UInt16(0))
        archiveData.append(littleEndian: entryCount)
        archiveData.append(littleEndian: entryCount)
        archiveData.append(littleEndian: centralDirectorySize)
        archiveData.append(littleEndian: centralDirectoryOffset)
        archiveData.append(littleEndian: UInt16(0))

        try archiveData.write(to: url, options: .atomic)
    }

    nonisolated private static func uint16(_ value: Int) throws -> UInt16 {
        guard let converted = UInt16(exactly: value) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return converted
    }

    nonisolated private static func uint32(_ value: Int) throws -> UInt32 {
        guard let converted = UInt32(exactly: value) else {
            throw CocoaError(.fileWriteUnknown)
        }

        return converted
    }

    nonisolated private static func dosDateTime(from date: Date) -> (date: UInt16, time: UInt16) {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )

        let year = max((components.year ?? 1980) - 1980, 0)
        let month = max(components.month ?? 1, 1)
        let day = max(components.day ?? 1, 1)
        let hour = max(components.hour ?? 0, 0)
        let minute = max(components.minute ?? 0, 0)
        let second = max(components.second ?? 0, 0) / 2

        let dosDate = UInt16((year << 9) | (month << 5) | day)
        let dosTime = UInt16((hour << 11) | (minute << 5) | second)

        return (dosDate, dosTime)
    }
}

private enum CRC32 {
    nonisolated static func checksum(for data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF

        for byte in data {
            crc ^= UInt32(byte)

            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB8_8320
                } else {
                    crc >>= 1
                }
            }
        }

        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    nonisolated mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
}
