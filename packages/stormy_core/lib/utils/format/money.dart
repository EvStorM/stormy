// 金额格式化
class MoneyFormat {
  // 如果小数点后为0，则去掉小数点
  static String format(double amount) {
    String formatted = amount.toStringAsFixed(2);

    // 如果小数点后都是0，则去掉小数点
    if (formatted.endsWith('.00')) {
      return formatted.substring(0, formatted.length - 3);
    }

    // 如果只有末尾是0，则去掉末尾的0
    if (formatted.endsWith('0')) {
      return formatted.substring(0, formatted.length - 1);
    }

    return formatted;
  }

  // 重载方法，支持字符串输入
  static String formatString(String amount) {
    double? value = double.tryParse(amount);
    if (value == null) return amount;
    return format(value);
  }
}
