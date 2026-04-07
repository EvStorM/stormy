// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get example_translations_badge => '角標';

  @override
  String example_translations_n_wombats(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString只袋熊',
      one: '1只袋熊',
      zero: '沒有袋熊',
    );
    return '$_temp0';
  }

  @override
  String example_translations_pronoun(String gender) {
    String _temp0 = intl.Intl.selectLogic(
      gender,
      {
        'male': '他',
        'female': '她',
        'other': '他/她',
      },
    );
    return '$_temp0';
  }

  @override
  String example_translations_money(int value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.compactCurrency(locale: localeName, decimalDigits: 2);
    final String valueString = valueNumberFormat.format(value);

    return '商品價格: $valueString';
  }

  @override
  String example_translations_hello_world_on(
      DateTime date, DateTime time, String name, int count, String gender) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.selectLogic(
      gender,
      {
        'male': '他',
        'female': '她',
        'other': '他/她',
      },
    );
    return '$dateString:$timeString 您好, $name, $_temp0已經有$countString個未讀消息';
  }
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get example_translations_badge => '角标';

  @override
  String example_translations_n_wombats(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString只袋熊',
      one: '1只袋熊',
      zero: '没有袋熊',
    );
    return '$_temp0';
  }

  @override
  String example_translations_pronoun(String gender) {
    String _temp0 = intl.Intl.selectLogic(
      gender,
      {
        'male': '他',
        'female': '她',
        'other': '他/她',
      },
    );
    return '$_temp0';
  }

  @override
  String example_translations_money(int value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.compactCurrency(locale: localeName, decimalDigits: 2);
    final String valueString = valueNumberFormat.format(value);

    return '商品价格: $valueString';
  }

  @override
  String example_translations_hello_world_on(
      DateTime date, DateTime time, String name, int count, String gender) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.selectLogic(
      gender,
      {
        'male': '他',
        'female': '她',
        'other': '他/她',
      },
    );
    return '$dateString:$timeString 您好, $name, $_temp0已经有$countString个未读消息';
  }
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get example_translations_badge => '角標';

  @override
  String example_translations_n_wombats(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString只袋熊',
      one: '1只袋熊',
      zero: '沒有袋熊',
    );
    return '$_temp0';
  }

  @override
  String example_translations_pronoun(String gender) {
    String _temp0 = intl.Intl.selectLogic(
      gender,
      {
        'male': '他',
        'female': '她',
        'other': '他/她',
      },
    );
    return '$_temp0';
  }

  @override
  String example_translations_money(int value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.compactCurrency(locale: localeName, decimalDigits: 2);
    final String valueString = valueNumberFormat.format(value);

    return '商品價格: $valueString';
  }

  @override
  String example_translations_hello_world_on(
      DateTime date, DateTime time, String name, int count, String gender) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);
    final intl.DateFormat timeDateFormat = intl.DateFormat.jm(localeName);
    final String timeString = timeDateFormat.format(time);

    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.selectLogic(
      gender,
      {
        'male': '他',
        'female': '她',
        'other': '他/她',
      },
    );
    return '$dateString:$timeString 您好, $name, $_temp0已經有$countString個未讀消息';
  }
}
