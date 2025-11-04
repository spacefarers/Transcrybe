//
//  Helpers.swift
//  Transcryb
//
//  Utilities and extensions
//

import SwiftUI

// MARK: - Whitespace and Punctuation Normalizer for Whisper Output

/// Normalizes transcription output from Whisper by collapsing multiple spaces,
/// removing spaces before punctuation, ensuring proper spacing after punctuation,
/// and cleaning up newlines. This handles common artifacts from Whisper's tokenization.
func normalizeTranscription(_ raw: String) -> String {
    var s = raw

    // Unify line endings
    s = s.replacingOccurrences(of: "\r\n", with: "\n")

    // Remove leading/trailing spaces and newlines
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)

    // Collapse runs of spaces and tabs inside lines
    s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)

    // Remove space before common punctuation
    s = s.replacingOccurrences(of: " \\.", with: ".", options: .regularExpression)
         .replacingOccurrences(of: " ,", with: ",", options: .regularExpression)
         .replacingOccurrences(of: " !", with: "!", options: .regularExpression)
         .replacingOccurrences(of: " \\?", with: "?", options: .regularExpression)
         .replacingOccurrences(of: " :", with: ":", options: .regularExpression)
         .replacingOccurrences(of: " ;", with: ";", options: .regularExpression)
         .replacingOccurrences(of: " %", with: "%", options: .regularExpression)

    // Tighten spaces just inside parentheses and quotes
    s = s.replacingOccurrences(of: "\\( ", with: "(", options: .regularExpression)
         .replacingOccurrences(of: " \\)", with: ")", options: .regularExpression)
         .replacingOccurrences(of: " \\]", with: "]", options: .regularExpression)
         .replacingOccurrences(of: "\\[ ", with: "[", options: .regularExpression)
         .replacingOccurrences(of: " \\'", with: "'", options: .regularExpression)
         .replacingOccurrences(of: " \\\"", with: "\"", options: .regularExpression)

    // Ensure a single space after sentence punctuation when followed by a word/number
    s = s.replacingOccurrences(of: "([.,!?;:])(\\S)", with: "$1 $2", options: .regularExpression)

    // Collapse 3+ newlines to 2 to avoid giant gaps
    s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

    return s
}
