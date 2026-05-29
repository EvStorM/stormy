#!/usr/bin/env python3
import os
import sys
import subprocess
import argparse

def find_pubspec_with_dep(start_dir, dep_name):
    """Recursively search for a pubspec.yaml containing the specified dependency."""
    found_dirs = []
    for root, dirs, files in os.walk(start_dir):
        # Ignore common temporary/build folders
        dirs[:] = [d for d in dirs if d not in ('.dart_tool', 'build', '.git', '.idea', 'node_modules')]
        if 'pubspec.yaml' in files:
            pubspec_path = os.path.join(root, 'pubspec.yaml')
            try:
                with open(pubspec_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    if dep_name in content:
                        found_dirs.append(root)
            except Exception:
                pass
    return found_dirs

def main():
    parser = argparse.ArgumentParser(description="Stormy I18n CLI Helper Script")
    parser.add_argument("action", choices=["gen", "watch", "init"], help="Action to execute: gen, watch, or init")
    parser.add_argument("--path", default=None, help="Root path of the project to search from")
    args = parser.parse_args()

    # Determine workspace directory
    search_root = args.path if args.path else os.getcwd()
    print(f"Searching for packages with stormy_i18n dependency starting from: {search_root}")

    target_dirs = find_pubspec_with_dep(search_root, "stormy_i18n")
    if not target_dirs:
        print("Error: Could not find any package / project declaring 'stormy_i18n' in pubspec.yaml")
        sys.exit(1)

    # If there are multiple, choose the best one (prefer non-package main apps or stormy_kit)
    target_dir = target_dirs[0]
    for d in target_dirs:
        if d.endswith("stormy_kit") or "packages" not in d:
            target_dir = d
            break

    print(f"Executing 'dart run stormy_i18n {args.action}' inside: {target_dir}")
    
    try:
        # Run command synchronously or stream output for watch mode
        if args.action == "watch":
            process = subprocess.Popen(
                ["dart", "run", "stormy_i18n", "watch"],
                cwd=target_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True
            )
            print("Started watcher. Press Ctrl+C to stop.")
            while True:
                output = process.stdout.readline()
                if output == '' and process.poll() is not None:
                    break
                if output:
                    print(output.strip())
            rc = process.poll()
            sys.exit(rc)
        else:
            result = subprocess.run(
                ["dart", "run", "stormy_i18n", args.action],
                cwd=target_dir,
                capture_output=True,
                text=True
            )
            print(result.stdout)
            if result.returncode != 0:
                print(result.stderr, file=sys.stderr)
                sys.exit(result.returncode)
    except KeyboardInterrupt:
        print("\nWatcher terminated by user.")
    except Exception as e:
        print(f"Execution failed: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
