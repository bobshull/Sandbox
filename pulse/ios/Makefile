DERIVED_DATA := .scratch/xcode-derived
MODULE_CACHE := .scratch/module-cache
PROJECT := Pulse.xcodeproj
SCHEME := Pulse
TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 16

.PHONY: generate typecheck build test

generate:
	xcodegen generate

typecheck:
	mkdir -p $(MODULE_CACHE)
	xcrun --sdk iphoneos swiftc -typecheck -target arm64-apple-ios16.0 -parse-as-library -module-cache-path $(MODULE_CACHE) $(shell find Pulse -name '*.swift' -print)

build:
	mkdir -p $(DERIVED_DATA)
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination generic/platform=iOS -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO

test:
	mkdir -p $(DERIVED_DATA)
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(TEST_DESTINATION)' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO
