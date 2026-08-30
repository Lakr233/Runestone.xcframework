import Foundation

enum RunestoneCombinedQuery {
    static func fromFiles(at fileURLs: [URL]) -> TreeSitterLanguage.Query? {
        let rawQuery = fileURLs.compactMap { try? String(contentsOf: $0) }.joined(separator: "\n")
        if rawQuery.isEmpty {
            return nil
        }
        return TreeSitterLanguage.Query(string: rawQuery)
    }
}
