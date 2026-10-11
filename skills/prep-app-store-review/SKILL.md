---
name: prep-app-store-review
description: Prepare a routine Buoys iOS App Store version for the user's final review. Use when asked to archive and upload through Xcode, then prepare and save the App Store Connect draft. Never submit for review.
---

# Prepare a Buoys App Store version

Archive and upload the iOS app with Xcode. Prepare a saved draft in App Store Connect. Leave submission for review to the user.

## Scope and stop rules

This skill permits only these changes and actions:

- Set the requested version in both `BuoyData` and `BuoyDataWidgetExtension`. Keep their build numbers unchanged.
- Select the app scheme and generic iOS device destination, run **Product > Archive**, and upload with **Distribute App > App Store Connect**.
- Dismiss the completed upload window, close Xcode windows, and quit Xcode.
- Open App Store Connect in the user's local Chrome browser. Use the user's passkey for routine sign-in, subject to the browser and computer-use skills' permission rules.
- Create or reuse the draft for the requested iOS version.
- For the uploaded build's routine **Missing Compliance** prompt, select **None of the algorithms mentioned above** and save, only when the release still uses the established encryption configuration.
- Attach the uploaded build to that draft.
- Copy the current published version's promotional text into the new version.
- Draft **What's New in This Version** directly in the field and save it without asking the user to approve the wording first.
- Keep or select **Automatically release this version**, **Release update to all users immediately**, and **Keep existing rating**.
- Save and verify these fields and settings.

**Never click Add for Review, Submit for Review, or any equivalent control that adds the version to a review submission or sends it to Apple.** This rule also applies if such a control appears in a dialog. Do not start a review submission to check readiness.

Do not change screenshots, previews, description, keywords, support or privacy URLs, categories, age ratings, app privacy answers, review notes, review contact details, pricing, availability, agreements, or other metadata. Do not add TestFlight testers or start beta review. Do not change signing, entitlements, encryption configuration, source code, dependencies, or build numbers. Do not commit or push as part of this procedure.

If an error occurs, stop and report it. If Xcode or App Store Connect requires a new field, approval, agreement, authentication step beyond routine passkey sign-in, or a workflow outside the list above, stop and report it. Do not accept terms, guess answers, repair the project, choose another distribution route, or update unrelated fields to proceed. Do not retry a failed archive or upload without user direction.

Normal archive progress, upload progress, and Apple build processing are expected. Observe them with bounded waits. If progress cannot be verified, processing fails, or the time limit is reached, stop and report the current state. A tool error or an uncertain action outcome is also a stop condition; read the current state if possible, but do not repeat the action blindly.

## Release inputs and tool setup

1. Identify the `buoys` repository. The default location is `~/Projects/buoydata/buoys`; the Xcode project is `ios/BuoyData.xcodeproj`.
2. Obtain the target version from the user's request. Ask for it if it is missing. Do not infer a version increment or reuse `1.3.3` from the source session.
3. Read applicable `AGENTS.md` instructions, the working-tree status, the existing target versions and build numbers, and the changes since the current published release. Use these changes to draft release notes. Do not assume that each release contains only the last two commits. If the release content is unclear, ask before archiving.
4. Load the installed `cua-driver` and `browser-use` skills. Read the applicable macOS computer-use guidance. Follow their current setup, permission, observation, input, and verification rules. Do not copy old process IDs, window IDs, tokens, browser element references, or coordinates from the source session.
5. Use `cua-driver` for Xcode and native passkey UI when needed. Use `browser-use` for App Store Connect page content in local Chrome. Keep one App Store Connect working tab. Reuse a matching tab when possible; do not close the user's unrelated tabs.
6. Observe before each action and verify after it. A successful tool call alone does not prove a saved field, completed upload, or selected build. Keep actions in the background where the tools support it. Follow their permission rules before any foreground or desktop action.
7. Default limits: wait up to 30 minutes for the archive, 30 minutes for the upload, and 30 minutes for Apple build processing. Use a user-provided limit if present. Check progress at intervals, approximately once per minute for build processing. Do not restart work merely because it is still processing.

`docs/ADMIN.md` has a general deployment procedure. For this skill, the scope above excludes its optional screenshot changes and its submission step.

## Archive and upload in Xcode

1. Open Xcode and `ios/BuoyData.xcodeproj`. Confirm that the intended project is open.
2. Record the current build number for each target. In **Targets > BuoyData > General > Identity**, set **Version** to the requested version. Repeat for **BuoyDataWidgetExtension**. Leave **Build** unchanged in both targets. Verify both values after editing. If inspecting `project.pbxproj`, check the target's Debug and Release settings; do not overwrite unrelated configuration.
3. Select the **BuoyData** app scheme and **Any iOS Device (arm64)**, or the current Xcode label for the generic iOS device destination. Do not select a simulator. Do not run a simulator.
4. Invoke **Product > Archive** through the native menu. Wait for completion within the archive time limit. If it fails, stop and report the displayed error.
5. In Organizer, select the archive just created. Verify its app, version, build, and creation time. Do not select an older archive with a similar name. If needed, inspect the archived app and widget `Info.plist` files to confirm `CFBundleShortVersionString` and `CFBundleVersion`.
6. Select **Distribute App**, then **App Store Connect**. Use that route's recommended settings. **Do not select Custom**, including to change “Manage version and build number.” If the displayed version or build differs from the intended values, or the upload would require changes outside this skill, stop and report the mismatch.
7. Complete the normal App Store Connect upload prompts. Wait within the upload time limit. Require Xcode's **App upload complete** confirmation. An archive alone or an upload-start message is not proof of upload completion.
8. After upload completion, click **Done**, close Organizer and the project windows, and quit Xcode through its normal quit action. Verify that Xcode has exited. Do this before work on the App Store Connect draft. Do not force-quit or discard unsaved work; if cleanup encounters an error or an unexpected prompt, stop and report it.

## Prepare the App Store Connect draft

### Open the app and create the version

1. Open `https://appstoreconnect.apple.com/` in local Chrome. Use routine passkey sign-in if needed. Stop for unexpected credentials, MFA, consent, or an ambiguous account.
2. Open **Buoys: Live Ocean Data**, app ID **6756240428**, and verify its identity. Use the app's current navigation rather than a saved team URL.
3. Read the current published iOS version's **Promotional Text** and **What's New in This Version**, including the selected language. Keep the text for use below; do not edit the published version.
4. In **Distribution > iOS App**, create the requested version. If a draft already exists for that version, reuse it only after verifying that it is editable and belongs to this release. If another draft blocks creation, stop. Do not delete or replace it.
5. Confirm that the requested version has status **Prepare for Submission**.

### Check processing and resolve routine compliance

1. In **TestFlight > Build Uploads**, or the current UI location for upload status, find the uploaded version and build. Verify that Apple processing is **Complete**. Wait within the processing time limit if it is still processing. Stop if it fails or has another unresolved requirement.
2. If that build shows **Missing Compliance**, open **Manage** for that build. Select **None of the algorithms mentioned above** and **Save**. This answer is limited to the app's established encryption configuration, as used in the source session. If release changes introduce encryption, the prompt differs, or the answer is uncertain, stop and report it. Do not answer additional compliance questions or upload documents.
3. Verify that the compliance answer is saved and the build is available for attachment. The source session showed **Ready to Submit** after saving. This is a build status, not permission to submit the app version for review.

### Attach the build and save the permitted metadata

1. Return to the requested draft under **Distribution**. Select **Add Build**, choose the uploaded version and build, and confirm with **Done**. Verify the selection and save. If another build is already attached, stop rather than replace it. If the intended build is already attached, verify it and continue.
2. Copy **Promotional Text** from the current published version into the draft's corresponding language. Use the text read from App Store Connect, not a historical value or a local metadata file. Do not add or change languages; stop if required localization work is outside this procedure.
3. Write concise release notes in **What's New in This Version**, based on the release changes. For a small maintenance release, reuse the current published version's text if it still describes the changes. The source session used “Small update here, just some bug fixes and improvements.” Treat that as an example, not a required value. Do not claim features or fixes that are not in the release.
4. Enter the release notes directly in the field and save. **Do not pause for approval of the wording.** The user will review the saved draft before submission.
5. Confirm or select these settings:
   - **Automatically release this version**
   - **Release update to all users immediately** (the immediate, non-phased update option)
   - **Keep existing rating**
6. Save the permitted changes. Reload the draft and read back its version, attached build, promotional text, release notes, and release and rating settings. Confirm that the values persist and the version remains **Prepare for Submission**. If saving fails or any required value cannot be verified, stop and report it. Do not use a review submission control to validate the draft.
7. Leave Chrome on the saved draft page for the user's review. End this run's computer-use session when complete, following the tool skill's cleanup rules.

## Completion report

Report:

- The version and uploaded build, including the app and widget version/build checks.
- Upload completion and whether Xcode cleanup completed.
- Apple processing and export compliance status.
- The attached build, saved promotional text, and saved release notes. Include the release notes in the report for the user's review.
- The saved release and rating settings.
- The App Store Connect draft URL and **Prepare for Submission** status.
- **The version has not been submitted for review. The user must perform the final review and submission.**

If blocked, report the step, the displayed error or new requirement, the changes already saved, and any incomplete cleanup. Do not claim that the draft is ready when a required check is incomplete. Wait for user direction.

## Source workflow

This procedure is based on OpenCode session `ses_ed4a780f8ffes06L8JjHCY25ND`. That release used version `1.3.3`, build `1`. Those values are historical. The user corrected the distribution route to **App Store Connect**, performed Xcode cleanup, and approved the saved release and rating settings. This skill includes that cleanup and removes the release-note approval pause. Review submission remains a user action.
