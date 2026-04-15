//
//  CrossNoteSearchToolDescriptor.swift
//  VivaDicta
//
//  Created by Anton Novoselov on 2026.04.15
//

import Foundation

let crossNoteSearchToolName = "searchOtherNotes"

let crossNoteSearchToolDescription = """
Search the user's OTHER notes ONLY when the user explicitly asks whether they mentioned something elsewhere in their notes, asks to search other notes, or asks to find related notes beyond the current note or notes already in the conversation. Do NOT use this tool for summarizing, explaining, extracting insights from, or answering questions about the current note or notes already in the conversation. Prefer this tool over web search for the user's personal notes.
"""

let crossNoteSearchToolQueryArgumentDescription = """
A short topic or phrase to search for in the user's other notes, such as 'chess', 'burnout', or 'castling'
"""
