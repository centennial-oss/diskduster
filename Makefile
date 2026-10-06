.PHONY: build build-macos build-release-unsigned build-run-macos clean generate-appicons generate-build-info lint lint-fix-safe reset-defaults reset-perms run-macos test

# SwiftLint: https://github.com/realm/SwiftLint - `brew install swiftlint`
SWIFTLINT ?= $(shell command -v swiftlint 2>/dev/null)

PROJECT := DiskDuster.xcodeproj
SCHEME := DiskDuster
APP_NAME := DiskDuster
BUNDLE_ID ?= org.centennialoss.diskduster
DERIVED_DATA := build/DerivedData
DIST_DERIVED_DATA := dist/DerivedData

# App icon pipeline (same as the other Centennial OSS apps):
#   1. Composite assets/app-icon-large-transparent.png over assets/app-icon-background-large.png
#      -> assets/app-icon-large.png
#   2. Resize the composite into every macOS AppIcon size. 16 and 32 are center-cropped first so the artwork
#      stays legible at tiny sizes.
#   3. Copy the 128x128 icon to assets/app-icon.png for the README.
APPICON_DIR := DiskDuster/Assets.xcassets/AppIcon.appiconset
APPICON_SRC := $(APPICON_DIR)/AppIcon_1024.png
APPICON_SIZES := 16 32 64 128 256 512
APPICON_BG := assets/app-icon-background-large.png
APPICON_TRANSPARENT_SRC := assets/app-icon-large-transparent.png
APPICON_LARGE := assets/app-icon-large.png
APPICON_PREVIEW := assets/app-icon.png
APPICON_CROP := build/AppIcon_crop.png
# The duster is top-heavy (feathers up, handle down), so it sits a little below center to look balanced.
APPICON_FG_SIZE := 860
APPICON_FG_Y_OFFSET := -30

# Build info: BuildInfoGenerated.swift feeds the About screen. The checked-in copy says "localdev"; CI rewrites
# it. Override any value with environment variables, e.g.:
#   COMMIT=... DATE=... CONFIG=Release ARCH=universal make generate-build-info
BUILD_INFO := DiskDuster/AppData/BuildInfoGenerated.swift
COMMIT ?= $(shell git rev-parse HEAD 2>/dev/null || echo local)
DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%S.000Z")
CONFIG ?= Debug
ARCH ?= arm64

# Override the version at build time (e.g. TAGVER=1.0.0 make build-release-unsigned). Writes
# DiskDuster/Version.xcconfig so the app shows this version in About and Info.plist.
TAGVER ?=
VERSION_XCCONFIG := DiskDuster/Version.xcconfig
COPYRIGHT := Copyright © 2026 Centennial OSS Inc.

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

# Open the Debug app built by build-macos.
run-macos:
	open "build/$(APP_NAME).app"

# Build the Debug app, then open it if the build succeeded.
build-run-macos: build-macos run-macos

build-release-unsigned:
	mkdir -p dist
	@if [ -n "$(TAGVER)" ]; then \
		printf 'MARKETING_VERSION = %s\nCURRENT_PROJECT_VERSION = 1\nINFOPLIST_KEY_NSHumanReadableCopyright = %s\n' \
			"$(TAGVER)" "$(COPYRIGHT)" > $(VERSION_XCCONFIG); \
	fi
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

generate-appicons:
	@test -f $(APPICON_BG) || (echo "Missing: $(APPICON_BG)" && exit 1)
	@test -f $(APPICON_TRANSPARENT_SRC) || (echo "Missing: $(APPICON_TRANSPARENT_SRC)" && exit 1)
	@mkdir -p build
	@echo "Compositing $(APPICON_TRANSPARENT_SRC) onto $(APPICON_BG) -> $(APPICON_LARGE)"
	@swift scripts/composite-app-icon.swift $(APPICON_BG) $(APPICON_TRANSPARENT_SRC) $(APPICON_LARGE) \
		$(APPICON_FG_SIZE) $(APPICON_FG_Y_OFFSET)
	@cp $(APPICON_LARGE) $(APPICON_SRC)
	@for size in $(APPICON_SIZES); do \
		echo "Creating AppIcon_$$size.png from AppIcon_1024.png"; \
		if [ "$$size" = "16" ]; then \
			sips --cropToHeightWidth 780 780 $(APPICON_SRC) --out $(APPICON_CROP) >/dev/null && \
			sips -z 16 16 $(APPICON_CROP) --out $(APPICON_DIR)/AppIcon_16.png >/dev/null; \
		elif [ "$$size" = "32" ]; then \
			sips --cropToHeightWidth 880 880 $(APPICON_SRC) --out $(APPICON_CROP) >/dev/null && \
			sips -z 32 32 $(APPICON_CROP) --out $(APPICON_DIR)/AppIcon_32.png >/dev/null; \
		else \
			sips -z $$size $$size $(APPICON_SRC) --out $(APPICON_DIR)/AppIcon_$$size.png >/dev/null; \
		fi; \
	done
	@cp $(APPICON_DIR)/AppIcon_128.png $(APPICON_PREVIEW)
	@rm -f $(APPICON_CROP)
	@echo "Done writing AppIcons and $(APPICON_PREVIEW)"

generate-build-info:
	@printf '%s\n' \
		'// Generated by make generate-build-info.' \
		'// Do not edit this file by hand.' \
		'' \
		'enum BuildInfoGenerated {' \
		'    static let buildCommit = "$(COMMIT)"' \
		'    static let buildDate = "$(DATE)"' \
		'    static let buildConfiguration = "$(CONFIG)"' \
		'    static let buildArch = "$(ARCH)"' \
		'}' > $(BUILD_INFO)
	@echo "Wrote $(BUILD_INFO)"
