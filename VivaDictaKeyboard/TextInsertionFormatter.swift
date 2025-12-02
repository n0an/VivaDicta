//
//  TextInsertionFormatter.swift
//  VivaDictaKeyboard
//
//  Created by Anton Novoselov on 2025.11.29
//

import UIKit

class TextInsertionFormatter {

    struct InsertionContext {
        let textBefore: String
        let textAfter: String
        let charBeforeCursor: Character?
        let charAfterCursor: Character?
    }

    static func getInsertionContext(from proxy: UITextDocumentProxy) -> InsertionContext {
        let textBefore = proxy.documentContextBeforeInput ?? ""
        let textAfter = proxy.documentContextAfterInput ?? ""

        return InsertionContext(
            textBefore: textBefore,
            textAfter: textAfter,
            charBeforeCursor: textBefore.last,
            charAfterCursor: textAfter.first
        )
    }

    static func formatTextForInsertion(_ text: String, context: InsertionContext?) -> String {
        guard let context = context else {
            return text + " "
        }

        var formattedText = text
        formattedText = applySmartCapitalization(formattedText, context: context)
        formattedText = applySmartSpacing(formattedText, context: context)

        return formattedText
    }

    private static func applySmartSpacing(_ text: String, context: InsertionContext) -> String {
        var result = text

        if shouldAddSpaceBefore(context: context) {
            result = " " + result
        }

        if let charAfter = context.charAfterCursor {
            if !charAfter.isWhitespace && !charAfter.isPunctuation && !(result.last?.isWhitespace ?? false) {
                result = result + " "
            }
        } else {
            result = result + " "
        }

        return result
    }

    private static func shouldAddSpaceBefore(context: InsertionContext) -> Bool {
        guard let charBefore = context.charBeforeCursor else {
            return false
        }

        if charBefore.isWhitespace {
            return false
        }

        // After sentence-ending punctuation
        if charBefore == "." || charBefore == "!" || charBefore == "?" {
            return true
        }

        // After other punctuation
        if charBefore == "," || charBefore == ";" || charBefore == ":" || charBefore == "-" {
            return true
        }

        // After letters or numbers
        if charBefore.isLetter || charBefore.isNumber {
            return true
        }

        return false
    }

    private static func applySmartCapitalization(_ text: String, context: InsertionContext) -> String {
        guard !text.isEmpty else { return text }

        let shouldCapitalize = shouldCapitalizeFirstLetter(context: context)

        if shouldCapitalize {
            return text.prefix(1).uppercased() + text.dropFirst()
        } else {
            let firstWord = text.prefix(while: { !$0.isWhitespace && !$0.isPunctuation })
            let isAcronymOrProper = firstWord.allSatisfy { $0.isUppercase || !$0.isLetter }

            if !isAcronymOrProper {
                return text.prefix(1).lowercased() + text.dropFirst()
            }
        }

        return text
    }

    private static func shouldCapitalizeFirstLetter(context: InsertionContext) -> Bool {
        // At the beginning of text
        if context.textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        let trimmedBefore = context.textBefore.trimmingCharacters(in: .whitespaces)

        if trimmedBefore.isEmpty {
            return true
        }

        // After sentence-ending punctuation or newline
        if let lastChar = trimmedBefore.last {
            if lastChar == "." || lastChar == "!" || lastChar == "?" || lastChar == "\n" {
                return true
            }
        }

        return false
    }
}
