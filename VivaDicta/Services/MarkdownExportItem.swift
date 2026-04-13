//
//  MarkdownExportItem.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.13
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct MarkdownExportItem: Transferable {
    static let contentType = UTType(filenameExtension: "md") ?? .plainText

    let filename: String
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: contentType) { item in
            Data(item.text.utf8)
        }
        .suggestedFileName { item in
            item.filename
        }
    }
}
