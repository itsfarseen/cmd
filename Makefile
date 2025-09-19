SWIFT = swiftc
FRAMEWORKS = -framework Cocoa -framework Carbon -framework ApplicationServices -framework CoreFoundation
TARGET = AppSwitcher
SOURCE = main.swift
BUILD_DIR = build

all: $(BUILD_DIR)/$(TARGET)

run: $(BUILD_DIR)/$(TARGET)
	$(BUILD_DIR)/$(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(TARGET): $(SOURCE) | $(BUILD_DIR)
	$(SWIFT) -g $(FRAMEWORKS) -o $(BUILD_DIR)/$(TARGET) $(SOURCE)

clean:
	rm -rf $(BUILD_DIR)

install: $(BUILD_DIR)/$(TARGET)
	mkdir -p $(HOME)/Applications
	cp $(BUILD_DIR)/$(TARGET) $(HOME)/Applications/

.PHONY: all clean install
