#!/usr/bin/env python3
import os
import sys
import re

# List of third-party libraries that MUST NOT be directly imported by business modules
# because they are already exported and unified by stormy_kit.
FORBIDDEN_DIRECT_DEPS = {
    "dio", "hive_ce", "hive_ce_flutter", "easy_refresh", "flutter_smart_dialog",
    "riverpod", "hooks_riverpod", "flutter_hooks", "go_router", "flutter_screenutil",
    "talker", "permission_handler", "uuid", "url_launcher", "image_picker", "gal",
    "modal_bottom_sheet", "stormy_i18n"
}

def check_pubspec_dependency(file_path):
    """Analyzes a pubspec.yaml file and prints warnings if violating direct dependency rules."""
    package_name = ""
    direct_violations = []
    
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return False

    in_dependencies = False
    in_dev_dependencies = False
    
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
            
        # Parse package name
        name_match = re.match(r"^name:\s+(\w+)", stripped)
        if name_match:
            package_name = name_match.group(1)
            continue
            
        # Segment locks
        if stripped == "dependencies:":
            in_dependencies = True
            in_dev_dependencies = False
            continue
        elif stripped == "dev_dependencies:":
            in_dependencies = False
            in_dev_dependencies = True
            continue
        elif re.match(r"^\w+:", stripped): # Other root key
            in_dependencies = False
            in_dev_dependencies = False
            continue
            
        # Check dependency items under 'dependencies' section
        if in_dependencies:
            dep_match = re.match(r"^([\w\-]+):", stripped)
            if dep_match:
                dep_name = dep_match.group(1)
                if dep_name in FORBIDDEN_DIRECT_DEPS:
                    direct_violations.append(dep_name)

    # If it's stormy_kit itself, it is ALLOWED to declare these dependencies
    if package_name == "stormy_kit":
        return True

    if direct_violations:
        print(f"\n[WARNING] Package '{package_name}' ({file_path}) directly declares unified dependencies:")
        for viol in direct_violations:
            print(f"  ❌ '{viol}' - Should be removed! Use 'package:stormy_kit/stormy_kit.dart' instead.")
        return False
    
    return True

def check_navigator_key(root_dir):
    """Scans all Dart files for MaterialApp/CupertinoApp usage and verifies StormyDialog.navigatorKey is bound."""
    violations = []
    
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in ('.dart_tool', 'build', '.git')]
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        content = f.read()
                        
                    # Find MaterialApp, CupertinoApp or GoRouter instantiation
                    if "MaterialApp" in content or "CupertinoApp" in content or "GoRouter(" in content:
                        # Check if StormyDialog.navigatorKey is present in the file
                        if "StormyDialog.navigatorKey" not in content and "SmartDialog.navigatorKey" not in content:
                            violations.append(file_path)
                except Exception:
                    pass
                    
    if violations:
        print("\n[WARNING] Found apps instantiating MaterialApp/CupertinoApp/GoRouter but missing StormyDialog.navigatorKey:")
        for viol in violations:
            print(f"  ❌ {viol} - Ensure you bind 'navigatorKey: StormyDialog.navigatorKey' to enable context-free dialogs.")
        return False
        
    return True

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
    print(f"Starting Stormy Code Architecture Scan at: {root_dir}")
    
    success = True
    
    # 1. Scan pubspec files
    pubspec_files = []
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in ('.dart_tool', 'build', '.git', '.idea', 'node_modules')]
        if "pubspec.yaml" in files:
            pubspec_files.append(os.path.join(root, "pubspec.yaml"))
            
    for pubspec in pubspec_files:
        if not check_pubspec_dependency(pubspec):
            success = False
            
    # 2. Check navigatorKey bindings
    if not check_navigator_key(root_dir):
        success = False
        
    if success:
        print("\n✅ All checks passed successfully! Dependencies and dialog bindings conform to architectural specifications.")
        sys.exit(0)
    else:
        print("\n⚠️ Scan complete with warnings. Please fix the highlighted issues.")
        sys.exit(1)

if __name__ == "__main__":
    main()
