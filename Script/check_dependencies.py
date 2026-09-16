#!/usr/bin/env python3
"""Check package ownership and prevent reverse dependencies on the facade."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ALLOWED = {
    'stormy_core': set(),
    'stormy_platform': {'stormy_core'},
    'stormy_ui': {'stormy_core', 'stormy_platform', 'stormy_i18n'},
    'stormy_i18n': set(),
    'stormy_i18n_generator': set(),
    'stormy_china_pay': {'stormy_core', 'stormy_platform'},
    'stormy_store_pay': set(),
    'stormy_gromore': set(),
    'stormy_kit': {'stormy_core', 'stormy_platform', 'stormy_ui', 'stormy_i18n'},
}

def main():
    failures = []
    for name, allowed in ALLOWED.items():
        package = ROOT / 'packages' / name
        manifest = (package / 'pubspec.yaml').read_text()
        runtime = manifest.split('dependencies:\n', 1)[1].split('dev_dependencies:', 1)[0]
        refs = set(re.findall(r'^  (stormy_\w+):', runtime, re.M))
        for source in (package / 'lib').rglob('*.dart'):
            refs.update(re.findall(r"(?:import|export) ['\"]package:(stormy_\w+)/", source.read_text()))
        forbidden = refs - allowed - {name}
        if forbidden:
            failures.append(f'{name}: unexpected dependencies {sorted(forbidden)}')
    for failure in failures:
        print(failure)
    if not failures:
        print('All 9 package dependency boundaries passed.')
    return bool(failures)

if __name__ == '__main__':
    sys.exit(main())
