# VD2-06 Contact Channels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add distinct work/personal email, mobile/office phone, and LinkedIn/Instagram/Facebook channels to Contacts while preserving existing contact data.

**Architecture:** Keep the existing first-class `Contact`/`CreateContact` model and extend it with five new persisted values while mapping legacy `email` to `workEmail` and legacy `profile_url` to `linkedInURL`. A version-34 additive migration creates only the new columns; `WorkspaceViewModel` continues to own editor drafts and `ContactsView` remains presentation-only. The first verification boundary is a normally signed Debug build launched for product-owner review; automated tests and independent gates remain deferred until owner feedback settles.

**Tech Stack:** Swift, SwiftUI/AppKit, SQLCipher-backed SQLite migrations, Xcode signed Debug build.

## Global Constraints

- Work email uses the existing `contacts.email` value; LinkedIn uses the existing `contacts.profile_url` value. Do not discard or rewrite either legacy column.
- Add optional personal email, mobile phone, office phone, Instagram URL, and Facebook URL fields.
- Preserve user-entered phone display formatting and extensions. Derive a `tel:` target only when opening the number.
- Social URLs accept only absolute `http` or `https` URLs with a public hostname.
- The detail panel shows only populated channels and uses system email, telephone, and browser handlers.
- Cancel restores the previously selected contact without persisting draft changes.
- Add no dependencies, syncing, import, discovery, generic channel collection, additional networks, or generic website field.
- Before product-owner review, run only a normally signed Debug build, strict signature verification, and app launch. Do not run automated tests, QA, code review, architecture/security gates, dashboards, or delivery updates.
- Do not commit implementation changes before product-owner review.

## Planned File Structure

| File | Responsibility |
| --- | --- |
| `RekonPursuitCore/Workspace/WorkspaceModels.swift` | Contact and command field names plus validation errors. |
| `RekonPursuitCore/Workspace/Migrations.swift` | Additive version-34 contact-channel schema migration. |
| `RekonPursuitCore/Workspace/WorkspaceStore.swift` | Validation, create/update SQL, reads, and legacy-column mapping. |
| `RekonPursuit/WorkspaceViewModel.swift` | Draft fields, warnings, selection hydration, clearing, search, and commands. |
| `RekonPursuit/ContactsView.swift` | Contact-information editor and populated channel actions in detail. |
| `RekonPursuitCoreTests/WorkspaceStoreTests.swift` | Post-owner migration/persistence/validation regression coverage. |
| `RekonPursuitTests/WorkspaceViewModelTests.swift` | Post-owner draft hydration/cancel/search regression coverage. |
| `RekonPursuitUITests/RekonPursuitUITests.swift` | Post-owner focused create/edit/detail accessibility contract. |

---

### Task 1: Implement the approved contact channels

**Files:**
- Modify: `RekonPursuitCore/Workspace/WorkspaceModels.swift`
- Modify: `RekonPursuitCore/Workspace/Migrations.swift`
- Modify: `RekonPursuitCore/Workspace/WorkspaceStore.swift`
- Modify: `RekonPursuit/WorkspaceViewModel.swift`
- Modify: `RekonPursuit/ContactsView.swift`

**Interfaces:**
- Consumes: Existing `Contact`, `CreateContact`, `WorkspaceStore`, `WorkspaceViewModel`, and `ContactsView` ownership boundaries.
- Produces: `Contact.workEmail`, `personalEmail`, `mobilePhone`, `officePhone`, `linkedInURL`, `instagramURL`, and `facebookURL`; matching defaulted `CreateContact` parameters and view-model drafts.

- [ ] **Step 1: Extend the model without breaking existing call sites.**

  Rename the Swift-facing `email` and `profileURL` semantics and add defaulted fields so existing tests and fixtures can be migrated mechanically rather than all at once:

  ```swift
  struct Contact: Equatable {
      let id: String
      let name: String
      let employer: String
      let title: String
      let workEmail: String
      let personalEmail: String
      let mobilePhone: String
      let officePhone: String
      let linkedInURL: String
      let instagramURL: String
      let facebookURL: String
      let relationshipContext: String
      let notes: String
  }

  init(
      name: String,
      employer: String = "",
      title: String = "",
      workEmail: String = "",
      personalEmail: String = "",
      mobilePhone: String = "",
      officePhone: String = "",
      linkedInURL: String = "",
      instagramURL: String = "",
      facebookURL: String = "",
      relationshipContext: String = "",
      notes: String = ""
  )
  ```

  Update current `email:` fixture/call sites to `workEmail:` and current `profileURL:` fixture/call sites to `linkedInURL:` only where compilation requires it. Add `WorkspaceStoreError.invalidContactWorkEmail`, `.invalidContactPersonalEmail`, and `.invalidContactSocialURL` with messages naming the rejected channel type.

- [ ] **Step 2: Add the additive schema migration.**

  Set `WorkspaceMigrations.currentVersion` to `34`, add a stable version-34 checksum, and append a verified-snapshot transaction. Keep `email` and `profile_url` unchanged and add only:

  ```sql
  ALTER TABLE contacts ADD COLUMN personal_email TEXT NOT NULL DEFAULT '';
  ALTER TABLE contacts ADD COLUMN mobile_phone TEXT NOT NULL DEFAULT '';
  ALTER TABLE contacts ADD COLUMN office_phone TEXT NOT NULL DEFAULT '';
  ALTER TABLE contacts ADD COLUMN instagram_url TEXT NOT NULL DEFAULT '';
  ALTER TABLE contacts ADD COLUMN facebook_url TEXT NOT NULL DEFAULT '';
  ```

  Follow the existing idempotent `PRAGMA table_info(contacts)` pattern, then insert migration-history version 34 and update `schema_migrations` inside the same transaction.

- [ ] **Step 3: Persist and read all seven channels.**

  Expand the shared contact projection in this exact order:

  ```text
  id, name, employer, title,
  email, personal_email, mobile_phone, office_phone,
  profile_url, instagram_url, facebook_url,
  relationship_context, notes
  ```

  Use the projection for `contacts()`, opportunity-linked contacts, and same-employer contacts. Expand insert/update bindings and `contact(from:)` to 13 values. Map `email -> workEmail` and `profile_url -> linkedInURL`.

  In `validatedContact`, trim every new value; validate both emails independently with `isValidContactEmail`; validate all three social values with the existing absolute public-host URL rule. Phone values are accepted as trimmed human-readable strings and are not reformatted.

- [ ] **Step 4: Extend the view-model draft lifecycle.**

  Replace `contactEmail`/`contactProfileURL` with these explicit drafts:

  ```swift
  @Published var contactWorkEmail = ""
  @Published var contactPersonalEmail = ""
  @Published var contactMobilePhone = ""
  @Published var contactOfficePhone = ""
  @Published var contactLinkedInURL = ""
  @Published var contactInstagramURL = ""
  @Published var contactFacebookURL = ""
  ```

  Add `contactWorkEmailWarning`, `contactPersonalEmailWarning`, `contactLinkedInURLWarning`, `contactInstagramURLWarning`, and `contactFacebookURLWarning`; hydrate all fields in `selectContact`, include them in `contactCommand`, and clear them in `clearContactDraft`. Include both emails and both phone values in contact search; social URLs need not be searchable.

- [ ] **Step 5: Implement the editor and populated detail actions.**

  Add a **Contact information** section containing fields labeled `Work email`, `Personal email`, `Mobile phone`, `Office phone`, `LinkedIn`, `Instagram`, and `Facebook`, with stable accessibility identifiers `contact-work-email`, `contact-personal-email`, `contact-mobile-phone`, `contact-office-phone`, `contact-linkedin`, `contact-instagram`, and `contact-facebook`.

  Replace the two generic detail links with populated channel actions. Use `mailto:` for email, the helper below for phone, and the saved absolute URL for social profiles. The helper keeps a leading `+`, strips punctuation from the dialable number, and converts a trailing `ext`, `ext.`, or `x` suffix to `;ext=` while leaving the displayed field untouched:

  ```swift
  private func telephoneURL(for displayedValue: String) -> URL? {
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
  ```

  Each action must have a visible service/type label and an accessibility label containing the contact name. Do not render empty channels.

  Keep the existing pencil action, save/cancel routing, related-opportunity management, and delete ownership unchanged.

- [ ] **Step 6: Inspect the focused implementation diff; do not run tests or commit.**

  Review only the five named production files for accidental schema replacement, unrelated visual changes, new dependencies, test-host changes, or ownership changes. Correct compile-obvious inconsistencies without starting automated verification.

---

### Task 2: Build and launch the signed owner preview

**Files:** No source changes unless the build exposes a compiler error in Task 1.

**Interfaces:**
- Consumes: Task 1 implementation.
- Produces: A normally signed `RekonPursuit.app` opened for product-owner review.

- [ ] **Step 1: Create a project-specific temporary build directory.**

  ```bash
  preview_root=$(mktemp -d /tmp/rekon-vd206-contact-channels.XXXXXX)
  ```

- [ ] **Step 2: Run one signed Debug build.**

  ```bash
  xcodebuild build \
    -project RekonPursuit.xcodeproj \
    -scheme RekonPursuit \
    -configuration Debug \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$preview_root/DerivedData"
  ```

  If compilation fails, repair only the direct Task 1 compiler error and repeat this one build. Do not expand into tests or unrelated cleanup.

- [ ] **Step 3: Verify and launch the signed app.**

  ```bash
  app_path="$preview_root/DerivedData/Build/Products/Debug/RekonPursuit.app"
  codesign --verify --deep --strict "$app_path"
  open "$app_path"
  ```

  Report the exact app path. Stop implementation activity and wait for product-owner feedback.

---

### Task 3: Incorporate product-owner feedback

**Files:** Only files required by explicit owner feedback.

**Interfaces:**
- Consumes: Product-owner observations from the launched signed app.
- Produces: A revised signed app for another owner look, or explicit owner confirmation that the contact-channel slice is ready for technical gates.

- [ ] **Step 1: Record each feedback item as an observable behavior.**

  Distinguish requested behavior changes from questions. Do not infer owner acceptance from silence or from approval of this plan.

- [ ] **Step 2: Implement only approved corrections.**

  Keep the Task 1 data mapping and migration compatibility intact unless the owner explicitly changes those decisions.

- [ ] **Step 3: Repeat only Task 2's signed build, signature verification, and launch.**

  Continue the owner-feedback loop until the owner explicitly authorizes technical gates.

---

### Task 4: Add proportionate regression coverage and resume independent VD2-06 gates

**Blocked until:** The product owner explicitly says the visual/interaction feedback loop is settled and authorizes technical gates.

**Files:**
- Modify: `RekonPursuitCoreTests/WorkspaceStoreTests.swift`
- Modify: `RekonPursuitTests/WorkspaceViewModelTests.swift`
- Modify: `RekonPursuitUITests/RekonPursuitUITests.swift`
- Modify production files only for test-proven defects.

**Interfaces:**
- Consumes: Owner-reviewed Task 3 implementation.
- Produces: Focused persistence, draft, validation, accessibility, relaunch, and independent-review evidence.

- [ ] **Step 1: Add focused Core regression tests.**

  Add one migration test that starts from schema 33 with populated `email` and `profile_url`, migrates to 34, and proves they decode as `workEmail` and `linkedInURL` while all new fields default empty. Add create/update/reopen assertions for all seven channels and rejection/no-write assertions for malformed work email, personal email, and each social URL.

- [ ] **Step 2: Add focused view-model regression tests.**

  Prove selection hydrates all seven drafts, Cancel restoration rehydrates persisted values without activity writes, clearing a new draft clears all seven values, and search matches work email, personal email, mobile phone, and office phone.

- [ ] **Step 3: Add one focused signed UI contract.**

  Create/edit a fixture contact, verify the seven accessible editor fields, save, relaunch, and verify only populated detail actions are exposed with correct labels. Keep this separate from broad VD2-08 testing.

- [ ] **Step 4: Run only the new focused selectors and `git diff --check`.**

  Use unique temporary DerivedData/result paths and normally signed products. Do not launch broad suites unless a focused failure indicates a shared regression.

- [ ] **Step 5: Run the required independent persistence/security, code-review, QA/accessibility, architecture, TPM, and Delivery gates.**

  Reviewers must be independent of the implementer. Resolve only evidence-backed findings. Record the VD2-06 gate and dashboard state only after the reviews are accepted; owner-gated successor work remains blocked until explicit VD2-06 product-owner acceptance is recorded.
