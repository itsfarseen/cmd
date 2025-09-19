# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -std=c99
FRAMEWORKS = -framework CoreFoundation -framework ApplicationServices
LDFLAGS = $(FRAMEWORKS)

# Target executable
TARGET = appswitch
SOURCE = appswitch.c

# Install directory
PREFIX = /usr/local
BINDIR = $(PREFIX)/bin

# Default target
all: $(TARGET)

# Build the executable
$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) $(SOURCE) $(LDFLAGS) -o $(TARGET)

# Clean build artifacts
clean:
	rm -f $(TARGET)

# Rebuild everything
rebuild: clean all

# Debug build with symbols
debug: CFLAGS += -g -DDEBUG
debug: $(TARGET)

# Release build with optimizations
release: CFLAGS += -O2 -DNDEBUG
release: $(TARGET)

# Show help
help:
	@echo "Available targets:"
	@echo "  all      - Build the application (default)"
	@echo "  clean    - Remove build artifacts"
	@echo "  rebuild  - Clean and build"
	@echo "  debug    - Build with debug symbols"
	@echo "  release  - Build optimized release version"
	@echo "  help     - Show this help"

.PHONY: all clean rebuild debug release help
