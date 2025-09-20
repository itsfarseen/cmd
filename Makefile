TARGET = CmdN
BUILD_DIR = .build/debug
RELEASE_BUILD_DIR = .build/release
DIST_DIR = dist
APP_NAME = $(DIST_DIR)/CmdN.app

all:
	swift build

run:
	swift run

release:
	swift build --configuration release

build-app:
	swift build --configuration release
	mkdir -p $(APP_NAME)/Contents/MacOS
	cp $(RELEASE_BUILD_DIR)/$(TARGET) $(APP_NAME)/Contents/MacOS/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(APP_NAME)/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(APP_NAME)/Contents/Info.plist
	@echo '<plist version="1.0">' >> $(APP_NAME)/Contents/Info.plist
	@echo '<dict>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<key>CFBundleExecutable</key>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<string>$(TARGET)</string>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<key>CFBundleIdentifier</key>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<string>itsfarseen.cmdn</string>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<key>CFBundleName</key>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<string>CmdN</string>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<key>CFBundleVersion</key>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<string>1.0</string>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<key>CFBundleShortVersionString</key>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<string>1.0</string>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<key>LSUIElement</key>' >> $(APP_NAME)/Contents/Info.plist
	@echo '	<true/>' >> $(APP_NAME)/Contents/Info.plist
	@echo '</dict>' >> $(APP_NAME)/Contents/Info.plist
	@echo '</plist>' >> $(APP_NAME)/Contents/Info.plist
	@echo "App bundle created at $(APP_NAME)"

clean:
	rm -rf $(BUILD_DIR) $(RELEASE_BUILD_DIR) $(DIST_DIR)

install:
	swift build
	mkdir -p $(HOME)/Applications
	cp $(BUILD_DIR)/$(TARGET) $(HOME)/Applications/

install-app:
	$(MAKE) build-app
	cp -r $(APP_NAME) /Applications/
	@echo "App installed to /Applications/CmdN.app"

package-zip:
	$(MAKE) build-app
	cd $(DIST_DIR) && zip -r ../$(TARGET).zip CmdN.app
	@echo "Created downloadable ZIP: $(TARGET).zip"

package-dmg:
	$(MAKE) build-app
	hdiutil create -volname "$(TARGET)" -srcfolder $(APP_NAME) -ov -format UDZO $(DIST_DIR)/$(TARGET).dmg
	@echo "Created downloadable DMG: $(DIST_DIR)/$(TARGET).dmg"

format:
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format --in-place *.swift ConfigurationUI/*.swift; \
		echo "Formatted all Swift files"; \
	else \
		echo "swift-format not found. Install with: brew install swift-format"; \
	fi

.PHONY: all clean install format release build-app install-app package-zip package-dmg
