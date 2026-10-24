# Build InstantSpaces with Swift Package Manager and assemble the app bundle.
#
#   make            debug build, no bundle
#   make test       run the tests
#   make app        build/InstantSpaces.app with the login helper and Sparkle embedded
#   make run        make app, then open it
#   make clean
#
# SIGN_IDENTITY names a signing identity (see `security find-identity -v -p codesigning`).
# Without it the app is signed ad hoc, which is enough to run it on this Mac.
# ARCHS=universal builds arm64 and x86_64; the default is this Mac's architecture.

SIGN_IDENTITY ?= -
ARCHS ?= native

ifeq ($(ARCHS),universal)
ARCH_FLAGS := --arch arm64 --arch x86_64
endif

# A secure timestamp needs Apple's timestamp server; ad-hoc signatures cannot have one.
ifeq ($(SIGN_IDENTITY),-)
TIMESTAMP := --timestamp=none
else
TIMESTAMP := --timestamp
endif

APP := build/InstantSpaces.app
HELPER := $(APP)/Contents/Library/LoginItems/InstantSpacesLoginHelper.app
SPARKLE := $(APP)/Contents/Frameworks/Sparkle.framework
SIGN := codesign --force --options runtime $(TIMESTAMP) --sign "$(SIGN_IDENTITY)"

.PHONY: debug test app run clean

debug:
	swift build

test:
	swift test

app:
	swift build -c release $(ARCH_FLAGS) --product InstantSpaces
	swift build -c release $(ARCH_FLAGS) --product LoginHelper
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Frameworks" "$(HELPER)/Contents/MacOS"
	# ditto keeps the symbolic links inside the framework.
	BIN="$$(swift build -c release $(ARCH_FLAGS) --show-bin-path)"; \
	cp "$$BIN/InstantSpaces" "$(APP)/Contents/MacOS/InstantSpaces"; \
	cp "$$BIN/LoginHelper" "$(HELPER)/Contents/MacOS/InstantSpacesLoginHelper"; \
	ditto "$$BIN/Sparkle.framework" "$(SPARKLE)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp Resources/LoginHelper-Info.plist "$(HELPER)/Contents/Info.plist"
	# Sign inside out: Sparkle's helpers, Sparkle, the login helper, then the app
	# that contains them. The order and the flags follow Sparkle's documentation
	# ("Code Signing", sparkle-project.org/documentation/sandboxing).
	$(SIGN) "$(SPARKLE)/Versions/B/XPCServices/Installer.xpc"
	$(SIGN) --preserve-metadata=entitlements "$(SPARKLE)/Versions/B/XPCServices/Downloader.xpc"
	$(SIGN) "$(SPARKLE)/Versions/B/Autoupdate"
	$(SIGN) "$(SPARKLE)/Versions/B/Updater.app"
	$(SIGN) "$(SPARKLE)"
	$(SIGN) "$(HELPER)"
	$(SIGN) "$(APP)"
	codesign --verify --strict --verbose=1 "$(APP)"
	@echo "Built $(APP) (signed with: $(SIGN_IDENTITY))"

run: app
	open "$(APP)"

clean:
	rm -rf .build build
