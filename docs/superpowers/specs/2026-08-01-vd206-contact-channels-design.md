# VD2-06 Contact Channels Design

## Goal

Extend Contacts so a person can retain distinct work and personal communication channels without losing the existing email or profile data.

## Approved fields

All fields are optional:

- Work email: the existing `Email` value, relabeled in the UI.
- Personal email: a second email address.
- Mobile phone.
- Office phone, stored as user-entered text so extensions and familiar formatting are preserved.
- LinkedIn URL: the existing `Profile URL` value, relabeled and migrated without data loss.
- Instagram URL.
- Facebook URL.

## User experience

The create and edit contact views group these fields under **Contact information**. The detail panel shows only populated channels so an incomplete contact does not accumulate empty rows.

- Email addresses open through the system email handler.
- Phone numbers open through the system telephone handler when a usable dial target can be derived. The displayed value remains exactly as entered.
- LinkedIn, Instagram, and Facebook actions open the saved URL in the default browser and use service-specific labels or icons.
- Existing compact pencil editing in the detail panel remains the entry point for editing a selected contact.
- Cancel returns to the previously selected contact without saving draft changes.

## Data and compatibility

The Contact model, create/update command, view-model draft, and local persistence schema gain first-class values for the new channels. Existing `email` data becomes work email. Existing `profileURL` data becomes LinkedIn. The storage migration must preserve both values and keep previously created contacts readable.

Whitespace-only values normalize to empty. Populated email and URL values use the same non-blocking editor guidance and authoritative save-time validation pattern as the existing fields. Social URLs must use `http` or `https`; phone values accept human-readable formatting and extensions.

## Delivery sequence

1. Implement the approved model, persistence, editor, and detail-panel changes.
2. Perform only the minimum build and launch checks necessary to provide a signed app.
3. Relaunch the app for product-owner review and incorporate feedback.
4. Only after owner feedback settles, run proportionate automated tests and the independent VD2-06 review gates.

## Out of scope

- Arbitrary user-defined communication-channel collections.
- Additional social networks or a generic website field.
- Contact syncing, address-book import, or social-profile discovery.
- Automated normalization that rewrites the displayed phone number.

## Owner-review criteria

- Create and edit expose all seven approved channels with clear labels.
- Saved values survive app relaunch.
- Existing email and profile data appear as Work email and LinkedIn respectively.
- The detail panel presents only populated channels and opens the correct system action.
- Cancelling an edit returns to the prior contact without applying draft changes.
