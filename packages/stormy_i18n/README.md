# stormy_i18n

[English](README.md) | [中文](README_zh.md)

`stormy_i18n` is a powerful and developer-friendly Flutter package that streamlines application localization. It solves the pain point of managing raw, JSON-like `.arb` files manually by allowing developers to define translations natively right inside Dart. Through strict typed constraints (`I18nItem`) and built-in CLI automation, it produces `.arb` files dynamically and invokes standard `flutter gen-l10n` out-of-the-box. 

### Key Features
- **Dart-native Definitions:** Define multi-language translations inside your Dart files by simply creating static `I18nItem` constants. 
- **Auto ARB Generation:** Automatically parses Dart code and produces standard `.arb` translations under the hood.
- **Type Safety & ICU Support:** Leverage pure Dart classes (`I18nPlaceholder`) to build pluralities, genders, monetary formats, and DateTime models easily.
- **Hot-Reload Watcher:** Optional `--watch` command monitors Dart source modifications for real-time localization regeneration.
- **Dynamic Locale Management:** Built-in Locale state machine with seamless App persistence handling (`StormyI18n.init()` & `StormyI18n.changeLocale()`).
- **BuildContext Extension:** Effortlessly fetch string definitions using a type-safe Context extension (`context.l10n.xxx`).

### Quick Start (Simple Usage)

1. **Install the package**
Add `stormy_i18n` into your `pubspec.yaml`:
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  stormy_i18n: any # Put latest version

flutter:
  generate: true # Must enable code generation
```

2. **Initialize configuration**
Run the initialization CLI command. It will create a `stormy_i18n.yaml` and a set of scaffolded setup code in `lib/i18n`:
```bash
dart run stormy_i18n init
```

3. **Define your translations**
Inside your translated source directory (default `lib/i18n`), create/edit Dart files. Define sentences using `I18nItem`:
```dart
import 'stormy_i18n.dart'; // Import generated scaffold

class AppTexts {
  static const appName = I18nItem(
    zh: '我的应用',
    en: 'My App',
  );
}
```

4. **Generate and Connect**
Execute the generator to process elements:
```bash
dart run stormy_i18n gen
```
Finally, initialize the controller and wrap `MaterialApp`:
```dart
import 'i18n/stormy_i18n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StormyI18n.init(); // Establish the locale controller
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to changes explicitly
    return ValueListenableBuilder<Locale?>(
      valueListenable: StormyI18n.localeNotifier,
      builder: (_, locale, __) {
        return MaterialApp(
          locale: locale,
          supportedLocales: StormyLocales.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomePage(),
        );
      }
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Access fully typed translation properties seamlessly!
    return Text(context.l10n.appName);
  }
}
```

### Advanced Features

#### 1. Complex Placeholders and ICU Support
You can supply dynamically formatted arguments using `I18nPlaceholder` bindings to construct plurals, numbers, date-times and complex sentence structures in ICU format:

```dart
class AdvancedTexts {
  // Setup Pluralization text
  static const nWombats = I18nItem(
    description: 'Notice message based on count',
    zh: '{count, plural, =0{没有袋熊} =1{1只袋熊} other{{count}只袋熊}}',
    en: '{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}',
    placeholders: {
      'count': I18nPlaceholder.int(format: 'compact'),
    },
  );

  // Time & Date format configuration
  static const dateInfo = I18nItem(
    zh: '今天日期是 {date}',
    en: 'Today is {date}',
    placeholders: {
      'date': I18nPlaceholder.dateTime(format: 'yMd'),
    },
  );
}
```

#### 2. Native File Watcher (Development)
Instead of invoking `gen` every time manually during development, keep the watcher running:
```bash
dart run stormy_i18n watch
```
It actively listens to save events from your translations matching `.dart` extensions, and rapidly re-compiles underlying ARB definitions.

#### 3. Custom Language Switching and Storage Persistence
`StormyI18n` abstracts tedious cache logic using two optional standard hooks (`localeResolver` to pull past setup and `onSave` to backup states). Great paired with caching systems like `shared_preferences`:
```dart
await StormyI18n.init(
  defaultLocale: const Locale('en'),
  // Hook to restore previous selection on App Boot
  localeResolver: () async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString('language');
    if (cache == null) return null;
    final parts = cache.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  },
  // Hook to save Locale once user switches
  onSave: (locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      prefs.remove('language'); // null equals hardware system fallback
    } else {
      prefs.setString('language', locale.toString()); // E.g., zh_CN saves here
    }
  },
);

// Switch user language programmatically globally
await StormyI18n.changeLocale(const Locale('zh', 'CN'));
```
