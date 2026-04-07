import '../stormy_i18n.dart';

class ExampleTranslations {
  static const badge = I18nItem(
    zh_CN: '角标',
    en_US: 'Badges',
    zh_TW: '角標',
  );

  static const nWombats = I18nItem(
    description: 'A plural message',
    zh_CN: '{count, plural, =0{没有袋熊} =1{1只袋熊} other{{count}只袋熊}}',
    en_US:
        '{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}',
    zh_TW: '{count, plural, =0{沒有袋熊} =1{1只袋熊} other{{count}只袋熊}}',
    placeholders: {
      'count': I18nPlaceholder.int(format: 'compact'),
    },
  );

  static const pronoun = I18nItem(
    description: 'A gendered message',
    zh_CN: '{gender, select, male{他} female{她} other{他/她}}',
    en_US: '{gender, select, male{he} female{she} other{they}}',
    zh_TW: '{gender, select, male{他} female{她} other{他/她}}',
    placeholders: {
      'gender': I18nPlaceholder.string(),
    },
  );

  static const money = I18nItem(
    description: 'A message with a formatted int parameter',
    zh_CN: '商品价格: {value}',
    en_US: 'Price: {value}',
    zh_TW: '商品價格: {value}',
    placeholders: {
      'value': I18nPlaceholder.intCompactCurrency(
        decimalDigits: 2,
      ),
    },
  );

  static const helloWorldOn = I18nItem(
    description: 'A message with a date parameter',
    zh_CN:
        '{date}:{time} 您好, {name}, {gender, select, male{他} female{她} other{他/她}}已经有{count}个未读消息',
    en_US:
        ' {name} Hello World on {date}:{time}, {gender, select, male{he} female{she} other{they}} have {count} unread {count, plural, =1{message} other{messages}}',
    zh_TW:
        '{date}:{time} 您好, {name}, {gender, select, male{他} female{她} other{他/她}}已經有{count}個未讀消息',
    placeholders: {
      'date': I18nPlaceholder.dateTime(format: 'yMd'),
      'time': I18nPlaceholder.dateTime(format: 'jm'),
      'name': I18nPlaceholder.string(),
      'count': I18nPlaceholder.int(format: 'compact'),
      'gender': I18nPlaceholder.string(),
    },
  );
}
