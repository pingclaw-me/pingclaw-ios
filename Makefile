.PHONY: dev build archive upload submit clean

# Local development — build and run on connected device via xtool
dev:
	cd PingClaw && xtool dev

# Full App Store build and upload
submit: clean archive upload

# Generate Xcode project, archive, export, and upload to App Store Connect
archive:
	cd XcodeApp && xcodegen generate
	cd XcodeApp && xcodebuild \
		-project PingClaw.xcodeproj \
		-scheme PingClaw \
		-sdk iphoneos \
		-configuration Release \
		-destination generic/platform=iOS \
		archive \
		-archivePath ./build/PingClaw.xcarchive \
		-allowProvisioningUpdates

upload:
	cd XcodeApp && xcodebuild \
		-exportArchive \
		-archivePath ./build/PingClaw.xcarchive \
		-exportPath ./build/upload \
		-exportOptionsPlist ExportOptions.plist \
		-allowProvisioningUpdates

# Build without uploading (exports IPA locally)
build: clean archive
	cd XcodeApp && xcodebuild \
		-exportArchive \
		-archivePath ./build/PingClaw.xcarchive \
		-exportPath ./build/export \
		-exportOptionsPlist ExportOptionsLocal.plist \
		-allowProvisioningUpdates

clean:
	rm -rf XcodeApp/build
