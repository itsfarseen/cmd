#!/usr/bin/env python3
"""
macOS App Build System
Builds Swift apps into .app bundles and creates installer DMGs
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# ============================================================================
# CONFIGURATION CONSTANTS
# ============================================================================

# Build Configuration
TARGET_NAME = "CmdN"
BUNDLE_ID = "itsfarseen.cmdn"
APP_VERSION = "1.0"
BUILD_CONFIG = "release"

# Directory Structure
BUILD_DIR = ".build"
RELEASE_BUILD_DIR = f"{BUILD_DIR}/release"
DIST_DIR = "dist"
ICONS_DIR = "icons"

# App Bundle Structure
APP_BUNDLE_NAME = f"{TARGET_NAME}.app"
APP_BUNDLE_PATH = f"{DIST_DIR}/{APP_BUNDLE_NAME}"

# Icon Configuration
ICON_FILE = "cmdn.png"
ICON_PATH = f"{ICONS_DIR}/{ICON_FILE}"
BUNDLE_ICON_NAME = "AppIcon.png"

# DMG Configuration
DMG_VOLUME_NAME = f"{TARGET_NAME} Installer"
DMG_WINDOW_WIDTH = 400
DMG_WINDOW_HEIGHT = 250
DMG_ICON_SIZE = 80

# Swift Build Commands
SWIFT_BUILD_DEBUG = ["swift", "build"]
SWIFT_BUILD_RELEASE = ["swift", "build", "--configuration", "release"]
SWIFT_RUN = ["swift", "run"]

# Swift Format
SWIFT_FORMAT_CMD = ["swift-format", "--in-place"]
SWIFT_FORMAT_PATTERNS = ["*.swift", "ConfigurationUI/*.swift"]


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def run_command(cmd, cwd=None, check=True, capture_output=False):
    """Run a shell command and return the result"""
    try:
        if capture_output:
            result = subprocess.run(cmd, cwd=cwd, check=check, capture_output=True, text=True)
        else:
            # For live output, don't set text=True and let stdout/stderr inherit from parent
            result = subprocess.run(cmd, cwd=cwd, check=check)
        return result
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {' '.join(cmd)}")
        if capture_output and hasattr(e, 'stderr'):
            print(f"Error: {e.stderr}")
        if check:
            sys.exit(1)
        return e

def ensure_dir(path):
    """Create directory if it doesn't exist"""
    Path(path).mkdir(parents=True, exist_ok=True)

def remove_if_exists(path):
    """Remove file or directory if it exists"""
    path = Path(path)
    if path.exists():
        if path.is_dir():
            shutil.rmtree(path)
        else:
            path.unlink()


# ============================================================================
# LAYOUT CALCULATION
# ============================================================================

def calculate_icon_positions(window_width, window_height, icon_size, num_items=2):
    """
    Calculate icon positions using flexbox-like layout:
    - align-items: center (vertical centering)
    - justify-content: space-around (horizontal distribution)

    Args:
        window_width: Width of the DMG window
        window_height: Height of the DMG window
        icon_size: Size of each icon
        num_items: Number of items to position (default: 2 for app + Applications)

    Returns:
        List of (x, y) tuples for each item position
    """
    # Account for window chrome and padding
    usable_width = window_width - 40  # Leave 20px padding on each side
    usable_height = window_height - 40  # Leave 20px padding top/bottom

    # Vertical center (align-items: center)
    center_y = (window_height // 2)

    # Horizontal distribution (justify-content: space-around)
    # space-around means equal space before first item, between items, and after last item
    total_space = usable_width - (num_items * icon_size)
    space_unit = total_space // (num_items + 1)  # +1 for space-around behavior

    positions = []
    for i in range(num_items):
        x = 20 + space_unit + (i * (icon_size + space_unit)) + (icon_size // 2)
        y = center_y
        positions.append((x, y))

    return positions


# ============================================================================
# PLIST GENERATION
# ============================================================================

def generate_info_plist(executable_name, bundle_id, app_name, version):
    """Generate Info.plist content"""
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>{executable_name}</string>
	<key>CFBundleIdentifier</key>
	<string>{bundle_id}</string>
	<key>CFBundleName</key>
	<string>{app_name}</string>
	<key>CFBundleVersion</key>
	<string>{version}</string>
	<key>CFBundleShortVersionString</key>
	<string>{version}</string>
	<key>LSUIElement</key>
	<true/>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
</dict>
</plist>"""


# ============================================================================
# DMG APPLESCRIPT
# ============================================================================

def generate_dmg_applescript(volume_name, app_name, window_width, window_height,
                           icon_size, app_x, app_y, applications_x, applications_y):
    """Generate AppleScript for DMG window configuration"""
    return f"""
tell application "Finder"
    tell disk "{volume_name}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {{100, 100, {100 + window_width}, {100 + window_height}}}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to {icon_size}
        set position of item "{app_name}" to {{{app_x}, {app_y}}}
        set position of item "Applications" to {{{applications_x}, {applications_y}}}
        update without registering applications
        delay 2
        close
    end tell
end tell
"""


# ============================================================================
# BUILD FUNCTIONS
# ============================================================================

def build_debug():
    """Build the Swift project in debug mode"""
    print("Building in debug mode...")
    run_command(SWIFT_BUILD_DEBUG)
    print("✅ Debug build complete")

def build_release():
    """Build the Swift project in release mode"""
    print("Building in release mode...")
    run_command(SWIFT_BUILD_RELEASE)
    print("✅ Release build complete")

def run_app():
    """Run the Swift project"""
    print("Running the app...")
    run_command(SWIFT_RUN)

def format_code():
    """Format Swift code using swift-format"""
    print("Formatting Swift code...")
    if shutil.which("swift-format"):
        for pattern in SWIFT_FORMAT_PATTERNS:
            try:
                run_command(SWIFT_FORMAT_CMD + [pattern], check=False)
            except:
                pass
        print("✅ Code formatted")
    else:
        print("swift-format not found. Install with: brew install swift-format")

def bundle_app():
    """Create the .app bundle"""
    print("Creating app bundle...")

    # Build release first
    build_release()

    # Clean and create bundle structure
    remove_if_exists(APP_BUNDLE_PATH)
    ensure_dir(f"{APP_BUNDLE_PATH}/Contents/MacOS")
    ensure_dir(f"{APP_BUNDLE_PATH}/Contents/Resources")

    # Copy executable
    executable_src = f"{RELEASE_BUILD_DIR}/{TARGET_NAME}"
    executable_dst = f"{APP_BUNDLE_PATH}/Contents/MacOS/{TARGET_NAME}"
    shutil.copy2(executable_src, executable_dst)

    # Copy icon
    icon_src = ICON_PATH
    icon_dst = f"{APP_BUNDLE_PATH}/Contents/Resources/{BUNDLE_ICON_NAME}"
    shutil.copy2(icon_src, icon_dst)

    # Generate Info.plist
    plist_content = generate_info_plist(TARGET_NAME, BUNDLE_ID, TARGET_NAME, APP_VERSION)
    plist_path = f"{APP_BUNDLE_PATH}/Contents/Info.plist"
    with open(plist_path, 'w') as f:
        f.write(plist_content)

    # Touch bundle to refresh icon cache
    Path(APP_BUNDLE_PATH).touch()

    print(f"✅ App bundle created at {APP_BUNDLE_PATH}")

def package_dmg():
    """Create installer DMG"""
    print("Creating installer DMG...")

    # Create app bundle first
    bundle_app()

    dmg_path = f"{DIST_DIR}/{TARGET_NAME}.dmg"
    staging_dir = f"{DIST_DIR}/staging"
    tmp_dmg = f"{DIST_DIR}/tmp_{TARGET_NAME}.dmg"

    # Clean staging area
    remove_if_exists(staging_dir)
    remove_if_exists(tmp_dmg)

    # Create staging directory
    ensure_dir(staging_dir)

    # Copy app bundle to staging
    shutil.copytree(APP_BUNDLE_PATH, f"{staging_dir}/{APP_BUNDLE_NAME}")

    # Create Applications symlink
    applications_link = f"{staging_dir}/Applications"
    if os.path.exists(applications_link):
        os.remove(applications_link)
    os.symlink("/Applications", applications_link)

    # Create writable DMG for customization
    cmd = [
        "hdiutil", "create",
        "-volname", DMG_VOLUME_NAME,
        "-srcfolder", staging_dir,
        "-ov", "-format", "UDRW",
        tmp_dmg
    ]
    run_command(cmd)

    # Mount DMG for customization
    cmd = ["hdiutil", "attach", "-readwrite", "-noverify", "-noautoopen", tmp_dmg]
    result = run_command(cmd, capture_output=True)

    # Parse mount point from hdiutil output
    mount_point = None
    for line in result.stdout.splitlines():
        if line.startswith("/dev/") and "/Volumes/" in line:
            parts = line.split()
            if len(parts) >= 1:
                mount_point = parts[0]
                break

    if not mount_point:
        print("Failed to determine mount point from hdiutil output")
        print("Available lines:")
        for line in result.stdout.splitlines():
            print(f"  {line}")
        sys.exit(1)

    volume_path = f"/Volumes/{DMG_VOLUME_NAME}"

    # Copy volume icon
    try:
        shutil.copy2(ICON_PATH, f"{volume_path}/.VolumeIcon.icns")
    except Exception as e:
        print(f"Warning: Could not set volume icon: {e}")

    # Calculate icon positions using flexbox-like layout
    positions = calculate_icon_positions(DMG_WINDOW_WIDTH, DMG_WINDOW_HEIGHT, DMG_ICON_SIZE)
    app_x, app_y = positions[0]
    applications_x, applications_y = positions[1]

    print(f"Positioning icons: App({app_x}, {app_y}), Applications({applications_x}, {applications_y})")

    # Configure DMG window with AppleScript
    applescript = generate_dmg_applescript(
        DMG_VOLUME_NAME, APP_BUNDLE_NAME,
        DMG_WINDOW_WIDTH, DMG_WINDOW_HEIGHT, DMG_ICON_SIZE,
        app_x, app_y, applications_x, applications_y
    )

    try:
        run_command(["osascript", "-e", applescript], check=False)
        print("DMG window configured with AppleScript")
    except Exception as e:
        print(f"Warning: AppleScript customization failed: {e}")

    # Wait before detaching
    time.sleep(2)

    # Detach the DMG
    detach_attempts = [
        ["hdiutil", "detach", mount_point, "-force"],
        ["hdiutil", "detach", volume_path, "-force"],
        ["diskutil", "eject", mount_point],
    ]

    detached = False
    for cmd in detach_attempts:
        try:
            run_command(cmd, check=False)
            detached = True
            break
        except:
            continue

    if not detached:
        print("Warning: Could not cleanly detach DMG, proceeding anyway...")

    time.sleep(1)

    # Convert to compressed, read-only DMG
    remove_if_exists(dmg_path)
    cmd = [
        "hdiutil", "convert", tmp_dmg,
        "-format", "UDZO",
        "-imagekey", "zlib-level=9",
        "-o", dmg_path
    ]

    # Retry conversion if needed
    max_retries = 3
    for attempt in range(max_retries):
        try:
            run_command(cmd)
            break
        except Exception as e:
            if attempt < max_retries - 1:
                print(f"DMG conversion failed, retrying... (attempt {attempt + 2}/{max_retries})")
                time.sleep(3)
            else:
                print(f"DMG conversion failed after {max_retries} attempts: {e}")
                # Create a basic compressed DMG as fallback
                fallback_cmd = [
                    "hdiutil", "create",
                    "-volname", DMG_VOLUME_NAME,
                    "-srcfolder", staging_dir,
                    "-ov", "-format", "UDZO",
                    dmg_path
                ]
                run_command(fallback_cmd)
                print("Created fallback DMG without customization")
                break

    # Clean up temporary files
    remove_if_exists(tmp_dmg)
    # Optionally keep staging dir for debugging: remove_if_exists(staging_dir)

    print(f"✅ Created installer DMG: {dmg_path}")

def clean():
    """Clean build artifacts"""
    print("Cleaning build artifacts...")
    remove_if_exists(BUILD_DIR)
    remove_if_exists(DIST_DIR)
    print("✅ Clean complete")


# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="macOS App Build System",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 build.py build          # Build in debug mode (default)
  python3 build.py run            # Run the app
  python3 build.py format         # Format Swift code
  python3 build.py build-release  # Build in release mode
  python3 build.py bundle-app     # Create .app bundle
  python3 build.py package-dmg    # Create installer DMG
  python3 build.py clean          # Clean build artifacts
        """
    )

    parser.add_argument(
        "command",
        choices=["build", "run", "format", "build-release", "bundle-app", "package-dmg", "clean"],
        nargs="?",
        default="build",
        help="Command to execute (default: build)"
    )

    args = parser.parse_args()

    # Execute the requested command
    if args.command == "build":
        build_debug()
    elif args.command == "run":
        run_app()
    elif args.command == "format":
        format_code()
    elif args.command == "build-release":
        build_release()
    elif args.command == "bundle-app":
        bundle_app()
    elif args.command == "package-dmg":
        package_dmg()
    elif args.command == "clean":
        clean()


if __name__ == "__main__":
    main()
