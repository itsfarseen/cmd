#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <stdio.h>
#include <string.h>

int switchToApp(const char* appName) {
    CFArrayRef runningApps = NULL;
    CFDictionaryRef app = NULL;
    CFStringRef cfAppName = NULL;
    CFNumberRef pidNumber = NULL;
    pid_t pid = 0;
    ProcessSerialNumber psn;
    OSStatus err;
    int found = 0;
    
    // Get list of all running applications
    CFStringRef keys[] = {kCGWindowOwnerName, kCGWindowOwnerPID};
    CFArrayRef keyArray = CFArrayCreate(NULL, (const void**)keys, 2, &kCFTypeArrayCallBacks);
    
    runningApps = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID
    );
    
    if (!runningApps) {
        printf("Failed to get running applications list\n");
        return 0;
    }
    
    CFIndex count = CFArrayGetCount(runningApps);
    
    // Search through running applications
    for (CFIndex i = 0; i < count; i++) {
        app = CFArrayGetValueAtIndex(runningApps, i);
        if (!app) continue;
        
        cfAppName = CFDictionaryGetValue(app, kCGWindowOwnerName);
        if (!cfAppName) continue;
        
        // Convert CFString to C string for comparison
        char currentAppName[256];
        if (CFStringGetCString(cfAppName, currentAppName, sizeof(currentAppName), kCFStringEncodingUTF8)) {
            // Case-insensitive partial match
            if (strcasestr(currentAppName, appName) != NULL) {
                pidNumber = CFDictionaryGetValue(app, kCGWindowOwnerPID);
                if (pidNumber) {
                    CFNumberGetValue(pidNumber, kCFNumberSInt32Type, &pid);
                    found = 1;
                    break;
                }
            }
        }
    }
    
    if (found && pid > 0) {
        // Convert PID to ProcessSerialNumber
        err = GetProcessForPID(pid, &psn);
        if (err == noErr) {
            // Bring the application to front
            err = SetFrontProcess(&psn);
            if (err == noErr) {
                printf("Switched to: %s (PID: %d)\n", appName, pid);
                found = 1;
            } else {
                printf("Failed to bring application to front (error: %d)\n", err);
                found = 0;
            }
        } else {
            printf("Failed to get process serial number (error: %d)\n", err);
            found = 0;
        }
    } else {
        printf("Application '%s' not found or not running\n", appName);
    }
    
    // Cleanup
    if (runningApps) CFRelease(runningApps);
    if (keyArray) CFRelease(keyArray);
    
    return found;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: %s <app_name>\n", argv[0]);
        printf("Example: %s Safari\n", argv[0]);
        printf("Example: %s \"Visual Studio Code\"\n", argv[0]);
        return 1;
    }
    
    if (switchToApp(argv[1])) {
        return 0;
    } else {
        return 1;
    }
}
