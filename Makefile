TARGET = AppSwitcher
BUILD_DIR = .build/debug

all: $(BUILD_DIR)/$(TARGET)

run: $(BUILD_DIR)/$(TARGET)
	swift run

$(BUILD_DIR)/$(TARGET):
	swift build

clean:
	rm -rf $(BUILD_DIR)

install: $(BUILD_DIR)/$(TARGET)
	mkdir -p $(HOME)/Applications
	cp $(BUILD_DIR)/$(TARGET) $(HOME)/Applications/

format:
	@if command -v swift-format >/dev/null 2>&1; then \
		swift-format --in-place *.swift; \
		echo "Formatted all Swift files"; \
	else \
		echo "swift-format not found. Install with: brew install swift-format"; \
	fi

.PHONY: all clean install format $(BUILD_DIR)/$(TARGET)
