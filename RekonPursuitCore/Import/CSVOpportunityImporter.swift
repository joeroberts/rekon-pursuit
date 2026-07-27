import Foundation

enum CSVImportField: String, CaseIterable, Identifiable {
    case title, company, jobURL, jobDescription, notes, compensation, location, workArrangement, stage, nextAction, dueDate, applicationDate, responseState, responseDate, stageDate
    var id: String { rawValue }
    var label: String { switch self {
    case .title: "Job title"; case .company: "Company"; case .jobURL: "Job URL"; case .jobDescription: "Job description"; case .notes: "Notes"; case .compensation: "Compensation"; case .location: "Location"; case .workArrangement: "Work arrangement"; case .stage: "Pipeline stage"; case .nextAction: "Next action"; case .dueDate: "Due date"; case .applicationDate: "Applied date"; case .responseState: "Response state"; case .responseDate: "Response status date"; case .stageDate: "Stage changed date" } }
    var required: Bool { self == .title || self == .company }
    static func suggested(for header: String) -> CSVImportField? {
        let value = header.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aliases: [CSVImportField: Set<String>] = [.title:["title","job title","role"], .company:["company","employer"], .jobURL:["url","job url","posting url","link"], .jobDescription:["description","job description"], .notes:["notes","note"], .compensation:["compensation","salary","pay"], .location:["location","city","location/city"], .workArrangement:["work arrangement","work mode","remote/hybrid"], .stage:["stage","status","pipeline stage"], .nextAction:["next action","follow up","follow-up"], .dueDate:["due date","next action date","follow up date"], .applicationDate:["applied date","application date","date applied"], .responseState:["response","response status"], .responseDate:["response date","response received date","response status date"], .stageDate:["stage date","status date","stage changed date"]]
        return aliases.first(where: { $0.value.contains(value) })?.key
    }
}

struct CSVImportPreview: Equatable {
    let headers: [String]
    let sourceBasename: String
    let rawRows: [[String]]
    var mapping: [CSVImportField: Int]
    var rows: [CSVImportRow] { CSVOpportunityImporter.validate(rawRows: rawRows, mapping: mapping) }
    var invalidRowCount: Int { rows.filter { !$0.isValid }.count }
    var validRows: [CreateOpportunity] { rows.compactMap(\.opportunity) }
}

struct CSVImportRow: Equatable, Identifiable {
    let id: Int
    let sourceRow: Int
    let values: [CSVImportField: String]
    let reasons: [String]
    let opportunity: CreateOpportunity?
    var isValid: Bool { reasons.isEmpty && opportunity != nil }
    init(id: Int, opportunity: CreateOpportunity) { self.id = id; sourceRow = id; values = [:]; reasons = []; self.opportunity = opportunity }
    init(id: Int, sourceRow: Int, values: [CSVImportField: String], reasons: [String], opportunity: CreateOpportunity?) { self.id = id; self.sourceRow = sourceRow; self.values = values; self.reasons = reasons; self.opportunity = opportunity }
}

enum CSVDuplicateDecision: String, CaseIterable, Equatable { case create, updateSelectedFields, skip, keepSeparate }

struct CSVImportPlanRow: Equatable, Identifiable {
    let row: CSVImportRow
    let candidateID: String?
    let duplicateRationale: String?
    let candidateTitle: String?
    let candidateCompany: String?
    let candidateValues: [CSVImportField: String]
    var decision: CSVDuplicateDecision?
    var selectedFields: Set<CSVImportField> = []
    var id: Int { row.id }
    var isDuplicate: Bool { candidateID != nil }
    init(row: CSVImportRow, candidateID: String?, duplicateRationale: String?, candidateTitle: String? = nil, candidateCompany: String? = nil, candidateValues: [CSVImportField: String] = [:], decision: CSVDuplicateDecision?) { self.row = row; self.candidateID = candidateID; self.duplicateRationale = duplicateRationale; self.candidateTitle = candidateTitle; self.candidateCompany = candidateCompany; self.candidateValues = candidateValues; self.decision = decision }
}

struct CSVImportReport: Equatable {
    let id: String
    let importedCount: Int
    let updatedCount: Int
    let skippedCount: Int
    let duplicateKeptCount: Int
    let invalidCount: Int
    let failedCount: Int
    let sourceBasename: String
    let mappingSummary: String
    let createdAt: Date
    init(id: String, importedCount: Int, updatedCount: Int = 0, skippedCount: Int, duplicateKeptCount: Int, invalidCount: Int, failedCount: Int = 0, sourceBasename: String = "", mappingSummary: String = "", createdAt: Date) { self.id = id; self.importedCount = importedCount; self.updatedCount = updatedCount; self.skippedCount = skippedCount; self.duplicateKeptCount = duplicateKeptCount; self.invalidCount = invalidCount; self.failedCount = failedCount; self.sourceBasename = sourceBasename; self.mappingSummary = mappingSummary; self.createdAt = createdAt }
}

struct CSVImportReportRow: Equatable, Identifiable {
    let id: String
    let sourceRow: Int
    let outcome: String
    let reason: String
    let duplicateRationale: String
    let opportunityID: String?
    let title: String
    let company: String
}

enum CSVImportError: LocalizedError { case unreadableFile, malformedCSV, missingRequiredColumns, duplicateMappedColumn, validationBlocked
    var errorDescription: String? { switch self { case .unreadableFile: "The CSV must be UTF-8."; case .malformedCSV: "The CSV contains an unmatched quote."; case .missingRequiredColumns: "Map both Job title and Company before validating."; case .duplicateMappedColumn: "A source column can only be mapped once."; case .validationBlocked: "Fix the mapping before validating." } }
}

enum CSVOpportunityImporter {
    static func preview(data: Data, sourceBasename: String = "CSV import") throws -> CSVImportPreview {
        guard let text = String(data: data, encoding: .utf8) else { throw CSVImportError.unreadableFile }
        let records = try parse(text)
        guard let header = records.first, !header.isEmpty else { throw CSVImportError.missingRequiredColumns }
        let normalized = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var mapping: [CSVImportField: Int] = [:]
        for (index, item) in normalized.enumerated() { if let field = CSVImportField.suggested(for: item), mapping[field] == nil { mapping[field] = index } }
        return CSVImportPreview(headers: normalized, sourceBasename: sourceBasename, rawRows: Array(records.dropFirst()), mapping: mapping)
    }

    static func validate(rawRows: [[String]], mapping: [CSVImportField: Int]) -> [CSVImportRow] {
        rawRows.enumerated().map { offset, source in
            let values = Dictionary(uniqueKeysWithValues: mapping.map { field, index in (field, source.indices.contains(index) ? source[index].trimmingCharacters(in: .whitespacesAndNewlines) : "") })
            var reasons: [String] = []
            guard mapping[.title] != nil, mapping[.company] != nil else { return CSVImportRow(id: offset + 2, sourceRow: offset + 2, values: values, reasons: ["Map Job title and Company."], opportunity: nil) }
            if values[.title, default: ""].isEmpty { reasons.append("Job title is required.") }
            if values[.company, default: ""].isEmpty { reasons.append("Company is required.") }
            if let url = values[.jobURL], !url.isEmpty, !(["http", "https"].contains(URL(string: url)?.scheme?.lowercased() ?? "")) { reasons.append("Job URL must begin with http:// or https://.") }
            if let raw = values[.workArrangement], !raw.isEmpty, WorkArrangement(rawValue: raw) == nil { reasons.append("Work arrangement is not recognized.") }
            if let raw = values[.stage], !raw.isEmpty, PipelineStage(rawValue: raw) == nil { reasons.append("Pipeline stage is not recognized.") }
            if let raw = values[.responseState], !raw.isEmpty, ResponseState(rawValue: raw) == nil { reasons.append("Response state is not recognized.") }
            let parsed: (CSVImportField) -> Date? = { parseDate(values[$0] ?? "") }
            for field in [.dueDate, .applicationDate, .responseDate, .stageDate] as [CSVImportField] { if let value = values[field], !value.isEmpty, parsed(field) == nil { reasons.append("\(field.label) must use YYYY-MM-DD.") } }
            if let due = values[.dueDate], !due.isEmpty, values[.nextAction, default: ""].isEmpty { reasons.append("Due date requires a Next action.") }
            let response = ResponseState(rawValue: values[.responseState] ?? "") ?? .noResponseRecorded
            if response != .noResponseRecorded && parsed(.responseDate) == nil { reasons.append("A response status date is required for this response.") }
            let opportunity = reasons.isEmpty ? CreateOpportunity(title: values[.title]!, company: values[.company]!, stage: PipelineStage(rawValue: values[.stage] ?? "") ?? .saved, nextAction: values[.nextAction] ?? "", dueAt: parsed(.dueDate), jobURL: values[.jobURL] ?? "", jobDescription: values[.jobDescription] ?? "", notes: values[.notes] ?? "", compensation: values[.compensation], location: values[.location], workArrangement: WorkArrangement(rawValue: values[.workArrangement] ?? "") ?? .notSpecified, applicationDate: parsed(.applicationDate), responseState: response, responseEffectiveDate: parsed(.responseDate), stageChangedAt: parsed(.stageDate)) : nil
            return CSVImportRow(id: offset + 2, sourceRow: offset + 2, values: values, reasons: reasons, opportunity: opportunity)
        }
    }

    static func mappingIsValid(_ mapping: [CSVImportField: Int]) -> Bool { mapping[.title] != nil && mapping[.company] != nil && Set(mapping.values).count == mapping.values.count }
    static func parseDate(_ value: String) -> Date? { guard value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }; let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = .current; formatter.isLenient = false; formatter.dateFormat = "yyyy-MM-dd"; guard let date = formatter.date(from: value), formatter.string(from: date) == value else { return nil }; var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .current; return calendar.startOfDay(for: date) }
    private static func parse(_ text: String) throws -> [[String]] { var records:[[String]] = [[]], field = "", quoted = false; var index = text.startIndex; while index < text.endIndex { let c = text[index]; if c == "\"" { let next = text.index(after: index); if quoted && next < text.endIndex && text[next] == "\"" { field.append("\""); index = next } else { quoted.toggle() } } else if c == "," && !quoted { records[records.count-1].append(field); field = "" } else if c.isNewline && !quoted { records[records.count-1].append(field); field=""; records.append([]) } else { field.append(c) }; index = text.index(after: index) }; if quoted { throw CSVImportError.malformedCSV }; if !records.last!.isEmpty || !field.isEmpty { records[records.count-1].append(field) } else { records.removeLast() }; return records }
}
