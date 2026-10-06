.PHONY: build build-macos build-release-unsigned clean lint lint-fix-safe reset-defaults reset-perms test

# SwiftLint: https://github.com/realm/SwiftLint - `brew install swiftlint`
SWIFTLINT ?= $(shell command -v swiftlint 2>/dev/null)

PROJECT := DiskDuster.xcodeproj
SCHEME := DiskDuster
APP_NAME := DiskDuster
BUNDLE_ID ?= org.centennialoss.diskduster
DERIVED_DATA := build/DerivedData
DIST_DERIVED_DATA := dist/DerivedData

lint:
	@if [ -z "$(SWIFTLINT)" ]; then \
		echo "SwiftLint not found. Install with: brew install swiftlint" >&2; \
		exit 1; \
	fi
	@"$(SWIFTLINT)" lint --strict

# Autocorrect only low-risk rules (whitespace / file hygiene). Still review `git diff` and run tests.
# Optional: pass paths, e.g. `make lint-fix-safe FIX_PATHS="DiskDuster/Views/ContentView.swift"`
FIX_PATHS ?= DiskDuster DiskDusterTests
lint-fix-safe:
	@if [ -z "$(SWIFTLINT)" ]; then \
		echo "SwiftLint not found. Install with: brew install swiftlint" >&2; \
		exit 1; \
	fi
	@"$(SWIFTLINT)" lint --fix \
		--only-rule trailing_whitespace \
		--only-rule trailing_newline \
		--only-rule leading_whitespace \
		--only-rule trailing_semicolon \
		$(FIX_PATHS)

clean:
	rm -rf build dist

# Lint, run unit tests, then build the Debug app into build/.
build: test build-macos

build-macos:
	mkdir -p build
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED_DATA) -destination 'platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
	rm -rf "build/$(APP_NAME).app"
	cp -R "$(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app" build/

build-release-unsigned:
	mkdir -p dist
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release -derivedDataPath $(DIST_DERIVED_DATA) -destination 'generic/platform=macOS' build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
	rm -rf "dist/$(APP_NAME).app"
	cp -R "$(DIST_DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app" dist/

# Run unit tests (lint first). Tests only touch temporary folders, never the real home folder.
test: lint
	mkdir -p build
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED_DATA) -destination 'platform=macOS' test -only-testing:DiskDusterTests CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES

# Forget the Full Disk Access decision so the first-run experience can be tested again.
reset-perms:
	@tccutil reset SystemPolicyAllFiles $(BUNDLE_ID)

reset-defaults:
	@defaults delete $(BUNDLE_ID) 2>/dev/null || true
	@echo "Reset UserDefaults for $(BUNDLE_ID)"
