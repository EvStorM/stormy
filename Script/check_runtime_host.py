#!/usr/bin/env python3
"""Resolve isolated runtime hosts outside the Pub workspace."""
from pathlib import Path
import argparse
import json
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--flutter', default='flutter')
    args = parser.parse_args()
    parent = ROOT.parent / 'temp'
    parent.mkdir(exist_ok=True)
    for package in ['stormy_core', 'stormy_kit', 'stormy_ui']:
        fixture = Path(tempfile.mkdtemp(prefix=f'{package}_host_', dir=parent))
        (fixture / 'lib').mkdir()
        (fixture / 'pubspec.yaml').write_text(f'''name: runtime_host
environment:
  sdk: ^3.13.0
dependencies:
  flutter:
    sdk: flutter
  {package}:
    path: {ROOT / 'packages' / package}
''')
        usage = 'final client = StormyNetworkClient(config: StormyNetworkConfig(baseUrl: "https://example.com"));\n  client.dio.close();'
        if package == 'stormy_kit':
            usage += '\n  final config = await stormy().build(apply: false);\n  assert(config.validate().isValid);'
        if package == 'stormy_ui':
            usage += '\n  final model = AppModel.defaults();\n  assert(model.designSize.width > 0);'
        (fixture / 'lib/main.dart').write_text(f"import 'package:{package}/{package}.dart';\nFuture<void> main() async {{\n  {usage}\n}}\n")
        result = subprocess.run([args.flutter, 'pub', 'get'], cwd=fixture)
        if result.returncode: return result.returncode
        graph = json.loads((fixture / '.dart_tool/package_config.json').read_text())
        names = {p['name'] for p in graph['packages']}
        assert 'stormy_i18n_generator' not in names, names
        result = subprocess.run([args.flutter, 'analyze', '--no-pub'], cwd=fixture)
        if result.returncode: return result.returncode
        print(f'{package}: no generator dependency; isolated host passed at {fixture}', flush=True)
    return 0

if __name__ == '__main__':
    sys.exit(main())
