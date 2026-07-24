import Foundation

struct CSVImportPreview: Equatable {
    let validRows: [CreateOpportunity]
    let invalidRowCount: Int
}

enum CSVOpportunityImporter {
    static func preview(data: Data) throws -> CSVImportPreview {
        guard let text = String(data: data, encoding: .utf8) else { throw CSVImportError.unreadableFile }
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let headerLine = lines.first else { throw CSVImportError.missingRequiredColumns }
        let headers = parseLine(headerLine).map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let titleIndex = headers.firstIndex(of: "title"), let companyIndex = headers.firstIndex(of: "company") else { throw CSVImportError.missingRequiredColumns }
        var validRows: [CreateOpportunity] = []
        var invalidRowCount = 0
        for line in lines.dropFirst() {
            let fields = parseLine(line)
            let title = fields.indices.contains(titleIndex) ? fields[titleIndex] : ""
            let company = fields.indices.contains(companyIndex) ? fields[companyIndex] : ""
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { invalidRowCount += 1; continue }
            validRows.append(CreateOpportunity(title: title, company: company))
        }
        return CSVImportPreview(validRows: validRows, invalidRowCount: invalidRowCount)
    }

    private static func parseLine(_ line: String) -> [String] {
        var fields: [String] = [""]
        var inQuotes = false
        for character in line {
            if character == "\"" { inQuotes.toggle() }
            else if character == ",", !inQuotes { fields.append("") }
            else { fields[fields.count - 1].append(character) }
        }
        return fields
    }
}

enum CSVImportError: Error { case unreadableFile, missingRequiredColumns }
