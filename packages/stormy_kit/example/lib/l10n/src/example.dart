import '../stormy_i18n.dart';

class ExampleTranslations {
  static const badge = I18nItem(
    zhCN: '角标',
    enUS: 'Badge',
  );

  static const nWombats = I18nItem(
    description: 'A plural message',
    zhCN: '{count, plural, =0{没有袋熊} =1{1只袋熊} other{{count}只袋熊}}',
    enUS: '{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}',
    placeholders: {
      'count': I18nPlaceholder.int(format: 'compact'),
    },
  );

  static const pronoun = I18nItem(
    description: 'A gendered message',
    zhCN: '{gender, select, male{他} female{她} other{他/她}}',
    enUS: '{gender, select, male{he} female{she} other{they}}',
    placeholders: {
      'gender': I18nPlaceholder.string(),
    },
  );

  static const money = I18nItem(
    description: 'A message with a formatted int parameter',
    zhCN: '商品价格: {value}',
    enUS: 'Price: {value}',
    placeholders: {
      'value': I18nPlaceholder.intCompactCurrency(
        decimalDigits: 2,
      ),
    },
  );

  static const helloWorldOn = I18nItem(
    description: 'A message with a date parameter',
    zhCN:
        '{date}:{time} 您好, {name}, {gender, select, male{他} female{她} other{他/她}}已经有{count}个未读消息',
    enUS:
        ' {name} Hello World on {date}:{time}, {gender, select, male{he} female{she} other{they}} have {count} unread {count, plural, =1{message} other{messages}}',
    placeholders: {
      'date': I18nPlaceholder.dateTime(format: 'yMd'),
      'time': I18nPlaceholder.dateTime(format: 'jm'),
      'name': I18nPlaceholder.string(),
      'count': I18nPlaceholder.int(format: 'compact'),
      'gender': I18nPlaceholder.string(),
    },
  );
}
