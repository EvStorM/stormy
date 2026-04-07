import 'dart:math';

import 'package:uuid/uuid.dart';
import 'log_utils.dart';

class UuidUtils {
  /// 生成随机字符串
  ///
  /// 生成固定长度的随机字符串，包含大小写字母
  ///
  /// [num] 字符串长度，必须大于0
  ///
  /// 返回随机字符串
  static String getRandom(int num) {
    if (num <= 0) {
      StormyLog.w('UuidUtils.getRandom: 长度必须大于0');
      throw ArgumentError('长度必须大于0，当前值: $num');
    }
    const String alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    String result = '';
    final random = Random();
    for (var i = 0; i < num; i++) {
      result += alphabet[random.nextInt(alphabet.length)];
    }
    return result;
  }

  /// 获取UUID（组合版本）
  ///
  /// [length] 参数未使用，保留用于向后兼容
  ///
  /// 返回基于 v1 和 v4 组合生成的 v5 UUID
  static String getUuid(int length) {
    return getUuidV5(getUuidV1() + getUuidV4());
  }

  /// 获取uuid v1
  /// 基于当前时间生成的uuid
  /// 例如：6c84fb90-12c4-11e1-840d-7b25c5ee775a
  static String getUuidV1() {
    var uuid = const Uuid();
    var v1 = uuid.v1();
    return v1;
  }

  /// 获取uuid v4
  /// 基于mathRNG随机数生成的uuid
  /// 例如：110ec58a-a0f2-4ac4-8393-c866d813b8d1
  static String getUuidV4() {
    var uuid = const Uuid();
    var v4 = uuid.v4();
    return v4;
  }

  /// 获取uuid v5
  ///
  /// 基于 namespace + 内容生成的uuid
  /// 例如：c4a760a8-dbcf-5254-a0d9-6a4474bd1b62
  ///
  /// [content] 用于生成UUID的内容，不能为空
  ///
  /// 返回UUID字符串
  static String getUuidV5(String content) {
    if (content.isEmpty) {
      StormyLog.w('UuidUtils.getUuidV5: 内容不能为空');
      throw ArgumentError('内容不能为空');
    }
    var uuid = const Uuid();
    var v5 = uuid.v5(Namespace.url.name, content);
    return v5;
  }
}
