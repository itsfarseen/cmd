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

.PHONY: all clean install
