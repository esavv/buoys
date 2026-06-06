# Deployment process

1. In Xcode: Bump the version numbers. In the filetree, click on the root directory to view the project, then find "Targets" on the left. In **both** BuoyData and BuoyDataWidgetExtension targets, increment the version number in Identity. No code changes required to change version number.
2. Set the destination to "Any iOS Device (arm64)" in the device dropdown at the top-center of Xcode, or in Product > Destination. You can't archive while targeting a simulator or a specific device
3. Build an archive by running Product > Archive
4. Once the archive completes, the Organizer window pops up. Click "Distribute App" > "App Store Connect" > follow the prompts to upload
5. In App Store Connect: In the Apps view, create a new version in "iOS App" on the top left. Update promotional text, release notes ("What's New in This Version"), and add the build from the archive you've just distributed. Optionally, update screenshots and other metadata.
6. Submit for review via "Add for Review" on top right.

