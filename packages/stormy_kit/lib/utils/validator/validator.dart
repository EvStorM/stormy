// 中文姓名校验和圆点校验
bool isChineseName(String value) {
  return RegExp(r'^[\u4e00-\u9fa5·.]{2,20}$').hasMatch(value);
}

// 是否是手机号
bool isPhoneNumber(String phoneNumber) {
  // 正则
  final RegExp regex = RegExp(r'^(?:(?:\+|00)86)?1[3-9]\d{9}$');
  return phoneNumber.length == 11 && regex.hasMatch(phoneNumber);
}

// 校验身份证号码
bool isIDCard(String idCard) {
  // 正则
  final RegExp regExp = RegExp(
    r'^[1-9]\d{5}(?:18|19|20)\d{2}(?:0[1-9]|10|11|12)(?:0[1-9]|[1-2]\d|30|31)\d{3}[\dXx]$',
  );
  return idCard.length == 18 && regExp.hasMatch(idCard);
}

// 是数字
bool isNumber(String value) {
  return RegExp(r'^[0-9]*$').hasMatch(value);
}

// 是邮箱
bool isEmail(String value) {
  return RegExp(
    r'^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)+$',
  ).hasMatch(value);
}
