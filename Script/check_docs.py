#!/usr/bin/env python3
"""Compile-check complete Dart examples from the maintained package docs."""
from pathlib import Path
import argparse
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--dart', default='dart')
    args = parser.parse_args()
    destination = ROOT / 'temp' / 'documentation'
    destination.mkdir(parents=True, exist_ok=True)
    documents = [ROOT / 'docs/USAGE.md', ROOT / 'docs/MIGRATION.md']
    documents += sorted((ROOT / 'packages').glob('*/README.md'))
    documents.append(ROOT / 'packages/stormy_core/lib/utils/preload/README.md')
    count = 0
    # These examples define app-specific generated types, compiled against the
    # actual checked-in example output with the same locale configuration.
    localization = ROOT / 'packages/stormy_i18n/example/lib/l10n/stormy_i18n.dart'
    for document in documents:
        for index, block in enumerate(re.findall(r'```dart\n(.*?)```', document.read_text(), re.S)):
            if not re.search(r'^import ', block, re.M):
                continue  # Explicit fragments need a surrounding application.
            block = block.replace("'../stormy_i18n.dart'", repr(localization.as_uri()))
            target = destination / f'{document.parent.name}_{index}.dart'
            target.write_text(f'// Source: {document.relative_to(ROOT)} block {index}\n{block}')
            count += 1
    (destination / 'analysis_options.yaml').write_text('analyzer:\n  errors:\n    depend_on_referenced_packages: ignore\n')
    print(f'Checking {count} complete examples', flush=True)
    return subprocess.run([args.dart, 'analyze', str(destination)], cwd=ROOT).returncode

if __name__ == '__main__':
    sys.exit(main())
