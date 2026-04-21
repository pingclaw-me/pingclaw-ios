.PHONY: dev build archive upload submit clean bump version

# Local development — build and run on connected device via xtool
dev:
	cd PingClaw && xtool dev

# Full App Store build and upload (auto-bumps build number)
submit: bump clean archive upload

# Bump the build number in project.yml before archiving.
# This is the single source of truth — xcodegen reads it.
bump:
	@CURRENT=$$(grep 'CURRENT_PROJECT_VERSION' XcodeApp/project.yml | sed 's/[^0-9]//g'); \
	NEXT=$$((CURRENT + 1)); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"$$CURRENT\"/CURRENT_PROJECT_VERSION: \"$$NEXT\"/" XcodeApp/project.yml; \
	echo "Build number: $$CURRENT → $$NEXT"

# Show current version and build number
version:
	@VERSION=$$(grep 'MARKETING_VERSION' XcodeApp/project.yml | sed 's/[^0-9.]//g'); \
	BUILD=$$(grep 'CURRENT_PROJECT_VERSION' XcodeApp/project.yml | sed 's/[^0-9]//g'); \
	echo "Version $$VERSION ($$BUILD)"

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
