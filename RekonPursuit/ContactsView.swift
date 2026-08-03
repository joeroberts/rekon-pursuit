import AppKit
import SwiftUI

enum ContactActionURL {
    static func email(_ address: String) -> URL? {
        guard !address.isEmpty,
              ContactEmailValidator.isValid(address),
              let url = URL(string: "mailto:\(address)"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "mailto",
              components.path == address,
              components.query == nil,
              components.fragment == nil else { return nil }
        return url
    }

    static func phone(_ displayedValue: String) -> URL? {
        let trimmed = displayedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let expression = try? NSRegularExpression(
            pattern: #"(?i)^(.*?)(?:\s+(?:ext\.?|x)\s*(\d+))?$"#
        )
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = expression?.firstMatch(in: trimmed, range: range),
              let numberRange = Range(match.range(at: 1), in: trimmed) else { return nil }

        let number = String(trimmed[numberRange])
        let digits = number.filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        let prefix = number.trimmingCharacters(in: .whitespaces).hasPrefix("+") ? "+" : ""
        let extensionValue = Range(match.range(at: 2), in: trimmed).map { String(trimmed[$0]) }
        let target = prefix + digits + (extensionValue.map { ";ext=\($0)" } ?? "")
        return URL(string: "tel:\(target)")
    }

    static func social(_ address: String) -> URL? {
        guard PublicProfileURLValidator.isValid(address) else { return nil }
        return URL(string: address)
    }
}

struct ContactsView: View {
    @ObservedObject var model: WorkspaceViewModel
    let open: (Opportunity) -> Void
    let delete: (Contact) -> Void

    @State private var editorMode: EditorMode?
    @State private var contactBeforeEditing: Contact?
    @State private var showsCompactDetail = false
    @State private var showsRelatedOpportunities = false
    @State private var showsRelationshipContext = false
    @State private var showsNotes = false
    @State private var showsOpportunityRelationships = false
    @State private var showsContactOverflow = false
    @State private var focusReturnName = ""
    @State private var pointerActivatedKeyboardControl: KeyboardFocusControl?
    @FocusState private var focusedKeyboardControl: KeyboardFocusControl?
    @FocusState private var contactSearchIsFocused: Bool
    @FocusState private var editorNameIsFocused: Bool
    @FocusState private var focusedEditorNote: EditorNote?

    private enum EditorMode {
        case new
        case edit
    }

    private enum KeyboardFocusControl: Hashable {
        case row(String)
        case relatedDisclosure
        case manageRelated
    }

    private enum EditorNote: Hashable {
        case relationshipContext
        case notes
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < Self.wideLayoutMinimumWidth
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
                header(isCompact: isCompact)
                if isCompact {
                    compactContent
                } else {
                    wideContent
                }
            }
            .padding(RekonTheme.Spacing.screen)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                if !isCompact {
                    selectInitialContactIfNeeded()
                }
            }
            .onChange(of: isCompact) { compact in
                if compact {
                    showsCompactDetail = editorMode != nil
                } else {
                    showsCompactDetail = false
                    selectInitialContactIfNeeded()
                }
            }
            .onChange(of: focusedKeyboardControl) { _, focusedControl in
                if focusedControl != pointerActivatedKeyboardControl {
                    pointerActivatedKeyboardControl = nil
                }
            }
        }
        .sheet(isPresented: $showsOpportunityRelationships) {
            ContactOpportunityManagementSheet(model: model, open: open)
        }
    }

    private static let wideLayoutMinimumWidth: CGFloat = 900

    @ViewBuilder private func header(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                    Text("Contacts")
                        .font(.largeTitle.bold())
                    Text("Keep relationship context and opportunity connections together.")
                        .foregroundStyle(RekonTheme.secondaryText)
                }
                Spacer()
                Button("New contact") {
                    beginNewContact(isCompact: isCompact)
                }
                .accessibilityIdentifier("contact-new")
                .accessibilityLabel("New contact")
                .accessibilityHint("Opens a blank contact editor")
                .buttonStyle(.borderedProminent)
                .tint(RekonTheme.accent)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contacts-new")
    }

    private var wideContent: some View {
        HStack(spacing: RekonTheme.Spacing.section) {
            masterRegion(isCompact: false)
                .frame(minWidth: 280, idealWidth: 360, maxWidth: 430, maxHeight: .infinity)

            detailPresentationRegion(isCompact: false)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contact-wide-master-detail")
    }

    @ViewBuilder private var compactContent: some View {
        if showsCompactDetail {
            detailPresentationRegion(isCompact: true)
                .accessibilityIdentifier("contact-compact-detail")
        } else {
            masterRegion(isCompact: true)
        }
    }

    private func masterRegion(isCompact: Bool) -> some View {
        masterList(isCompact: isCompact)
    }

    private func detailPresentationRegion(isCompact: Bool) -> some View {
        detailRegion(isCompact: isCompact)
    }

    private func masterList(isCompact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
                searchAndFilter
                if model.filteredContacts.isEmpty {
                    emptyListState
                } else {
                    LazyVStack(spacing: RekonTheme.Spacing.tight) {
                        ForEach(model.filteredContacts, id: \.id) { contact in
                            contactRow(contact, isCompact: isCompact)
                        }
                    }
                }
            }
            .padding(RekonTheme.Spacing.compact)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("contacts-master-list")
        }
        .background(RekonTheme.surface, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: RekonTheme.Radius.card)
                .stroke(RekonTheme.borderSubtle)
        }
        .accessibilityIdentifier("contact-list-scroll")
    }

    private var searchAndFilter: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
            TextField("Search contacts", text: $model.contactSearch)
                .focused($contactSearchIsFocused)
                .accessibilityIdentifier("contact-search")
                .accessibilityLabel("Search contacts")
            Picker("Employer", selection: $model.contactEmployerFilter) {
                Text("All employers").tag("All employers")
                ForEach(model.contactEmployers, id: \.self) { Text($0).tag($0) }
            }
            .accessibilityLabel("Filter contacts by employer")
        }
    }

    @ViewBuilder private var emptyListState: some View {
        if hasActiveContactFilter {
            Text("No contacts match the current search or employer filter.")
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("contact-no-results-state")
        } else {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                Text("No contacts yet")
                    .font(.headline)
                Text("Create a contact to keep relationship context and opportunity links together.")
                    .foregroundStyle(RekonTheme.secondaryText)
            }
            .accessibilityIdentifier("contact-empty-state")
        }
    }

    private var hasActiveContactFilter: Bool {
        !model.contactSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || model.contactEmployerFilter != "All employers"
    }

    private func contactRow(_ contact: Contact, isCompact: Bool) -> some View {
        let isSelected = model.selectedContactID == contact.id
        return Button {
            selectContact(contact, isCompact: isCompact, pointerActivated: true)
        } label: {
            HStack(spacing: RekonTheme.Spacing.compact) {
                ContactInitialsBadge(contact: contact)
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                    HStack {
                        Text(contact.name)
                            .font(.headline)
                            .lineLimit(1)
                        if isSelected {
                            Text("Selected")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RekonTheme.primaryText)
                        }
                    }
                    Text([contact.title, contact.employer].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(RekonTheme.Spacing.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                        .fill(RekonTheme.actionGradient)
                        .opacity(0.3)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: RekonTheme.Radius.control)
                    .stroke(isSelected ? RekonTheme.accent : RekonTheme.borderSubtle, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .focusable()
        .focused($focusedKeyboardControl, equals: .row(contact.id))
        .onKeyPress(.space) {
            selectContact(contact, isCompact: isCompact, pointerActivated: false)
            return .handled
        }
        .focusEffectDisabled(true)
        .accessibilityIdentifier("contact-row-\(contactRowAccessibilitySlug(contact))")
        .accessibilityLabel("\(contact.name), \(isSelected ? "selected" : "not selected")")
        .accessibilityValue(
            keyboardAccessibilityValue(
                isSelected ? "Selected" : "Not selected",
                for: .row(contact.id)
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func detailRegion(isCompact: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
                if isCompact, showsCompactDetail, editorMode == nil {
                    Button("Back to Contacts") {
                        showsCompactDetail = false
                        focusSelectedRow()
                    }
                    .accessibilityIdentifier("contact-detail-back")
                    .accessibilityLabel("Back to Contacts")
                    .keyboardShortcut(.cancelAction)
                }

                if editorMode != nil {
                    contactEditor(isCompact: isCompact)
                } else if let contact = model.selectedContact {
                    contactDetail(contact)
                } else {
                    noSelectionState
                }
            }
            .padding(RekonTheme.Spacing.section)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("contacts-detail-region")
        }
        .background(RekonTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: RekonTheme.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: RekonTheme.Radius.card)
                .stroke(RekonTheme.borderSubtle)
        }
        .accessibilityIdentifier("contact-detail-scroll")
    }

    private var noSelectionState: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.compact) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.largeTitle)
                    .foregroundStyle(RekonTheme.secondaryText)
                Text("Select a contact")
                    .font(.title2.bold())
                    .accessibilityIdentifier("contact-no-selection-state")
                Text("Choose a contact to view its saved details, notes, and linked opportunities.")
                    .foregroundStyle(RekonTheme.secondaryText)
                Text("No related opportunities")
                    .foregroundStyle(RekonTheme.secondaryText)
                    .accessibilityIdentifier("contact-related-opportunities-empty-state")
            }
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .center)
        }
        .accessibilityElement(children: .contain)
    }

    private func contactDetail(_ contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.section) {
            HStack(alignment: .top, spacing: RekonTheme.Spacing.compact) {
                ContactInitialsBadge(contact: contact, size: 64)
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                    Text(contact.name)
                        .font(.title.bold())
                    Text([contact.title, contact.employer].filter { !$0.isEmpty }.joined(separator: " · "))
                        .foregroundStyle(RekonTheme.secondaryText)
                    contactLinks(contact)
                }
                Spacer()
                detailActions(contact)
            }

            if !contact.relationshipContext.isEmpty {
                disclosureSection(
                    title: "Relationship context",
                    content: contact.relationshipContext,
                    expanded: $showsRelationshipContext
                )
            }
            if !contact.notes.isEmpty {
                disclosureSection(title: "Notes", content: contact.notes, expanded: $showsNotes)
            }

            relatedOpportunities
            Text("Focus returns to \(focusReturnName.isEmpty ? contact.name : focusReturnName)")
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
                .accessibilityIdentifier("contact-focus-return")
                .accessibilityValue(focusReturnName.isEmpty ? contact.name : focusReturnName)
        }
    }

    @ViewBuilder private func contactLinks(_ contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            contactChannel(label: "Work email", displayedValue: contact.workEmail, targetURL: ContactActionURL.email(contact.workEmail), contactName: contact.name)
            contactChannel(label: "Personal email", displayedValue: contact.personalEmail, targetURL: ContactActionURL.email(contact.personalEmail), contactName: contact.name)
            contactChannel(label: "Mobile phone", displayedValue: contact.mobilePhone, targetURL: ContactActionURL.phone(contact.mobilePhone), contactName: contact.name)
            contactChannel(label: "Office phone", displayedValue: contact.officePhone, targetURL: ContactActionURL.phone(contact.officePhone), contactName: contact.name)
            contactChannel(label: "LinkedIn", displayedValue: contact.linkedInURL, targetURL: ContactActionURL.social(contact.linkedInURL), contactName: contact.name)
            contactChannel(label: "Instagram", displayedValue: contact.instagramURL, targetURL: ContactActionURL.social(contact.instagramURL), contactName: contact.name)
            contactChannel(label: "Facebook", displayedValue: contact.facebookURL, targetURL: ContactActionURL.social(contact.facebookURL), contactName: contact.name)
        }
        .buttonStyle(.link)
    }

    @ViewBuilder private func contactChannel(label: String, displayedValue: String, targetURL: URL?, contactName: String) -> some View {
        if !displayedValue.isEmpty {
            if let targetURL {
                Button {
                    NSWorkspace.shared.open(targetURL)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: RekonTheme.Spacing.tight) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(RekonTheme.secondaryText)
                        Text(displayedValue)
                    }
                }
                .accessibilityLabel("\(label) for \(contactName): \(displayedValue)")
            } else {
                HStack(alignment: .firstTextBaseline, spacing: RekonTheme.Spacing.tight) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                    Text(displayedValue)
                }
            }
        }
    }

    private func detailActions(_ contact: Contact) -> some View {
        HStack(spacing: RekonTheme.Spacing.tight) {
            Button {
                beginEdit(contact)
            } label: {
                Image(systemName: "pencil")
            }
            .accessibilityIdentifier("contact-edit")
            .accessibilityLabel("Edit contact")

            Button {
                showsContactOverflow = true
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityIdentifier("contact-overflow")
            .accessibilityLabel("Contact actions")
            .confirmationDialog("Contact actions", isPresented: $showsContactOverflow, titleVisibility: .hidden) {
                Button("Delete contact", role: .destructive) {
                    delete(contact)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .buttonStyle(.bordered)
    }

    private func disclosureSection(
        title: String,
        content: String,
        expanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
            Button {
                expanded.wrappedValue.toggle()
            } label: {
                Label(title, systemImage: expanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.headline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(expanded.wrappedValue ? "Expanded" : "Collapsed")
            if expanded.wrappedValue {
                Text(content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(RekonTheme.secondaryText)
            }
        }
    }

    private var relatedOpportunities: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
            VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                HStack {
                    Button {
                        toggleRelatedOpportunities(pointerActivated: true)
                    } label: {
                        Label(
                            "View related opportunities (\(model.selectedContactOpportunities.count))",
                            systemImage: showsRelatedOpportunities ? "chevron.down" : "chevron.right"
                        )
                        .font(.headline)
                    }
                    .buttonStyle(.plain)
                    .focusable()
                    .focused($focusedKeyboardControl, equals: .relatedDisclosure)
                    .onKeyPress(.space) {
                        toggleRelatedOpportunities(pointerActivated: false)
                        return .handled
                    }
                    .focusEffectDisabled(true)
                    .accessibilityIdentifier("contact-related-disclosure")
                    .accessibilityLabel("View related opportunities")
                    .accessibilityValue(
                        keyboardAccessibilityValue(
                            "\(showsRelatedOpportunities ? "Expanded" : "Collapsed"); \(model.selectedContactOpportunities.count) related opportunities",
                            for: .relatedDisclosure
                        )
                    )
                    Spacer()
                    Button("Manage") {
                        showOpportunityRelationshipManagement(pointerActivated: true)
                    }
                    .focusable()
                    .focused($focusedKeyboardControl, equals: .manageRelated)
                    .onKeyPress(.space) {
                        showOpportunityRelationshipManagement(pointerActivated: false)
                        return .handled
                    }
                    .focusEffectDisabled(true)
                    .accessibilityIdentifier("contact-manage-related")
                    .accessibilityLabel("Manage linked opportunities")
                    .accessibilityValue(keyboardAccessibilityValue("", for: .manageRelated))
                }
                if showsRelatedOpportunities {
                    if model.selectedContactOpportunities.isEmpty {
                        Text("No related opportunities")
                            .foregroundStyle(RekonTheme.secondaryText)
                            .accessibilityIdentifier("contact-related-opportunities-empty-state")
                    } else {
                        ForEach(model.selectedContactOpportunities, id: \.id) { opportunity in
                            HStack {
                                Text("\(opportunity.title) · \(opportunity.company)")
                                Spacer()
                                Button("Open") { open(opportunity) }
                            }
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("contact-related-opportunities")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("manage-contact-opportunities")
    }

    private func contactEditor(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
            Text(editorMode == .new ? "New contact" : "Edit contact")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(RekonTheme.secondaryText)
                    TextField("Name", text: $model.contactName)
                        .textFieldStyle(RekonQuietTextFieldStyle())
                        .focused($editorNameIsFocused)
                        .accessibilityIdentifier("contact-name")
                }

                employerEditor
                contactTextField("Title (optional)", text: $model.contactTitle)
            }

            contactSection("Contact information") {
                contactTextField("Work email", text: $model.contactWorkEmail, accessibilityIdentifier: "contact-work-email")
                if let warning = model.contactWorkEmailWarning {
                    validationMessage(warning)
                }
                contactTextField("Personal email", text: $model.contactPersonalEmail, accessibilityIdentifier: "contact-personal-email")
                if let warning = model.contactPersonalEmailWarning {
                    validationMessage(warning)
                }
                contactTextField("Mobile phone", text: $model.contactMobilePhone, accessibilityIdentifier: "contact-mobile-phone")
                contactTextField("Office phone", text: $model.contactOfficePhone, accessibilityIdentifier: "contact-office-phone")
                contactTextField("LinkedIn", text: $model.contactLinkedInURL, accessibilityIdentifier: "contact-linkedin")
                if let warning = model.contactLinkedInURLWarning {
                    validationMessage(warning)
                }
                contactTextField("Instagram", text: $model.contactInstagramURL, accessibilityIdentifier: "contact-instagram")
                if let warning = model.contactInstagramURLWarning {
                    validationMessage(warning)
                }
                contactTextField("Facebook", text: $model.contactFacebookURL, accessibilityIdentifier: "contact-facebook")
                if let warning = model.contactFacebookURLWarning {
                    validationMessage(warning)
                }
            }

            contactSection("Relationship notes") {
                editorExpandableText(
                    title: "Relationship context (optional)",
                    text: $model.contactRelationshipContext,
                    expanded: $showsRelationshipContext,
                    focus: .relationshipContext
                )
                editorExpandableText(
                    title: "Notes (optional)",
                    text: $model.contactNotes,
                    expanded: $showsNotes,
                    focus: .notes
                )
            }

            HStack {
                Button("Cancel") { cancelEditing(isCompact: isCompact) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { saveContact(isCompact: isCompact) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.contactName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("save-contact")
            }
            if let error = model.contactSaveError {
                VStack(alignment: .leading) {
                    Text(error)
                        .foregroundStyle(RekonTheme.danger)
                        .accessibilityIdentifier("contact-save-error")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("contact-operation-error")
                .accessibilityLabel(error)
            }
        }
    }

    @ViewBuilder private var employerEditor: some View {
        if model.isAddingNewContactEmployer {
            contactTextField("New employer (optional)", text: $model.contactEmployer)
            Button("Choose tracked employer") { model.chooseTrackedContactEmployer() }
        } else {
            contactTextField("Search tracked employers", text: $model.contactEmployerSearch, accessibilityIdentifier: "contact-employer-search")
            if !model.contactEmployer.isEmpty {
                HStack {
                    Text("Employer: \(model.contactEmployer)").foregroundStyle(RekonTheme.secondaryText)
                    Button("Clear") { model.chooseTrackedContactEmployer() }
                }
            }
            if !model.contactEmployerSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.filteredContactEmployerSuggestions, id: \.self) { employer in
                        Button(employer) { model.selectContactEmployer(employer) }
                    }
                    if let candidate = model.contactEmployerAddCandidate {
                        if !model.filteredContactEmployerSuggestions.isEmpty { Divider() }
                        Button("Add \(candidate) as new employer") {
                            model.beginNewContactEmployer(named: candidate)
                        }
                    }
                }
            }
        }
    }

    private func validationMessage(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(RekonTheme.warning)
    }

    @ViewBuilder private func contactTextField(
        _ title: String,
        text: Binding<String>,
        accessibilityIdentifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            Text(title)
                .font(.caption)
                .foregroundStyle(RekonTheme.secondaryText)
            if let accessibilityIdentifier {
                TextField(title, text: text)
                    .textFieldStyle(RekonQuietTextFieldStyle())
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                TextField(title, text: text)
                    .textFieldStyle(RekonQuietTextFieldStyle())
            }
        }
    }

    private func contactSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
            HStack(spacing: RekonTheme.Spacing.tight) {
                Text(title)
                    .font(.headline)
                Rectangle()
                    .fill(RekonTheme.borderSubtle)
                    .frame(height: 1)
            }
            content()
        }
    }

    private func editorExpandableText(
        title: String,
        text: Binding<String>,
        expanded: Binding<Bool>,
        focus: EditorNote
    ) -> some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.micro) {
            HStack {
                Text(title).font(.caption).foregroundStyle(RekonTheme.secondaryText)
                Spacer()
                Button(expanded.wrappedValue ? "Collapse" : "Expand") {
                    expanded.wrappedValue.toggle()
                }
                .accessibilityLabel(title)
                .accessibilityValue(expanded.wrappedValue ? "Expanded" : "Collapsed")
            }
            TextEditor(text: text)
                .focused($focusedEditorNote, equals: focus)
                .frame(minHeight: expanded.wrappedValue ? 132 : 64, maxHeight: expanded.wrappedValue ? 176 : 64)
                .rekonQuietTextEditorSurface(isFocused: focusedEditorNote == focus)
        }
    }

    private func beginNewContact(isCompact: Bool) {
        contactBeforeEditing = model.selectedContact
        model.beginNewContact()
        editorMode = .new
        if isCompact {
            showsCompactDetail = true
        }
        focusEditorName()
    }

    private func beginEdit(_ contact: Contact) {
        contactBeforeEditing = contact
        editorMode = .edit
        focusEditorName()
    }

    private func saveContact(isCompact: Bool) {
        if editorMode == .new {
            model.createContact()
        } else {
            model.saveSelectedContact()
        }
        guard model.contactSaveError == nil else { return }
        editorMode = nil
        contactBeforeEditing = nil
        if isCompact, model.selectedContact == nil {
            showsCompactDetail = false
        }
    }

    private func cancelEditing(isCompact: Bool) {
        let wasCreatingNewContact = editorMode == .new
        if let contactBeforeEditing {
            model.selectContact(contactBeforeEditing)
            focusReturnName = contactBeforeEditing.name
        } else {
            model.beginNewContact()
        }
        editorMode = nil
        self.contactBeforeEditing = nil

        if isCompact, wasCreatingNewContact {
            showsCompactDetail = false
            if model.selectedContact == nil {
                focusContactSearch()
            } else {
                focusSelectedRow()
            }
            return
        }

        if isCompact, model.selectedContact == nil {
            showsCompactDetail = false
            focusContactSearch()
            return
        }
        focusSelectedRow()
    }

    private func selectInitialContactIfNeeded() {
        guard model.selectedContact == nil, let contact = model.filteredContacts.first else { return }
        model.selectContact(contact)
        focusReturnName = contact.name
    }

    private func focusEditorName() {
        DispatchQueue.main.async {
            editorNameIsFocused = true
        }
    }

    private func focusSelectedRow() {
        guard let contact = model.selectedContact else { return }
        focusReturnName = contact.name
        DispatchQueue.main.async {
            focusedKeyboardControl = .row(contact.id)
        }
    }

    private func selectContact(_ contact: Contact, isCompact: Bool, pointerActivated: Bool) {
        if pointerActivated {
            pointerActivatedKeyboardControl = .row(contact.id)
        } else {
            pointerActivatedKeyboardControl = nil
        }
        model.selectContact(contact)
        focusReturnName = contact.name
        if isCompact {
            showsCompactDetail = true
        }
    }

    private func toggleRelatedOpportunities(pointerActivated: Bool) {
        pointerActivatedKeyboardControl = pointerActivated ? .relatedDisclosure : nil
        showsRelatedOpportunities.toggle()
    }

    private func showOpportunityRelationshipManagement(pointerActivated: Bool) {
        pointerActivatedKeyboardControl = pointerActivated ? .manageRelated : nil
        showsOpportunityRelationships = true
    }

    private func keyboardAccessibilityValue(
        _ existingValue: String,
        for control: KeyboardFocusControl
    ) -> String {
        guard focusedKeyboardControl == control, pointerActivatedKeyboardControl != control else {
            return existingValue
        }
        return existingValue.isEmpty ? "Keyboard focus" : "\(existingValue); Keyboard focus"
    }

    private func focusContactSearch() {
        DispatchQueue.main.async {
            contactSearchIsFocused = true
        }
    }

    private func contactRowAccessibilitySlug(_ contact: Contact) -> String {
        let baseSlug = contact.accessibilitySlug
        let hasNameCollision = model.contacts.filter { $0.accessibilitySlug == baseSlug }.count > 1
        guard hasNameCollision else { return baseSlug }
        return "\(baseSlug)-\(contact.accessibilityIDSuffix)"
    }
}

private struct ContactInitialsBadge: View {
    let contact: Contact
    var size: CGFloat = 36

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
            .foregroundStyle(RekonTheme.primaryText)
            .frame(width: size, height: size)
            .background(RekonTheme.actionGradient, in: Circle())
            .accessibilityHidden(true)
    }

    private var initials: String {
        let components = contact.name.split(whereSeparator: \.isWhitespace)
        let letters = components.prefix(2).compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}

private extension Contact {
    var accessibilitySlug: String {
        let slug = name.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
        return slug.isEmpty ? "contact" : slug
    }

    var accessibilityIDSuffix: String {
        id.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
    }
}

private struct ContactOpportunityManagementSheet: View {
    @ObservedObject var model: WorkspaceViewModel
    let open: (Opportunity) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var associationFailure: AssociationFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: RekonTheme.Spacing.standard) {
            Text("Manage linked opportunities")
                .font(.title2.bold())
            Text("Link only opportunities this person is connected to. Opening an opportunity does not change its association.")
                .foregroundStyle(RekonTheme.secondaryText)

            if model.selectedContactOpportunities.isEmpty {
                Text("This contact is not linked to an opportunity yet.")
                    .foregroundStyle(RekonTheme.secondaryText)
            } else {
                ForEach(model.selectedContactOpportunities, id: \.id) { opportunity in
                    HStack {
                        Text("\(opportunity.title) · \(opportunity.company)")
                        Spacer()
                        Button("Open") { open(opportunity); dismiss() }
                        Button("Unlink") { unlink(opportunity) }
                    }
                }
            }

            if !model.contactEmployer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !model.selectedContactUnlinkedEmployerOpportunities.isEmpty {
                Divider()
                Text("Other opportunities at \(model.contactEmployer)").font(.headline)
                ForEach(model.selectedContactUnlinkedEmployerOpportunities, id: \.id) { opportunity in
                    HStack {
                        Text("\(opportunity.title) · \(opportunity.company)")
                        Spacer()
                        Button("Open") { open(opportunity); dismiss() }
                        Button("Link") { link(opportunity) }
                    }
                }
            }

            if let associationFailure {
                VStack(alignment: .leading, spacing: RekonTheme.Spacing.tight) {
                    Text("\(associationFailure.actionName) failed. \(model.statusMessage)")
                        .foregroundStyle(RekonTheme.danger)
                    Button("Retry \(associationFailure.actionName)") {
                        retry(associationFailure)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("contact-operation-error")
                .accessibilityLabel("\(associationFailure.actionName) failed")
                .accessibilityValue(model.statusMessage)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(RekonTheme.Spacing.section)
        .frame(width: 560)
    }

    private enum AssociationFailure {
        case link(Opportunity)
        case unlink(Opportunity)

        var actionName: String {
            switch self {
            case .link:
                "Link"
            case .unlink:
                "Unlink"
            }
        }
    }

    private func link(_ opportunity: Opportunity) {
        model.linkSelectedContact(to: opportunity)
        associationFailure = model.selectedContactOpportunities.contains(where: { $0.id == opportunity.id })
            ? nil
            : .link(opportunity)
    }

    private func unlink(_ opportunity: Opportunity) {
        model.unlinkSelectedContact(from: opportunity)
        associationFailure = model.selectedContactOpportunities.contains(where: { $0.id == opportunity.id })
            ? .unlink(opportunity)
            : nil
    }

    private func retry(_ failure: AssociationFailure) {
        switch failure {
        case let .link(opportunity):
            link(opportunity)
        case let .unlink(opportunity):
            unlink(opportunity)
        }
    }
}
