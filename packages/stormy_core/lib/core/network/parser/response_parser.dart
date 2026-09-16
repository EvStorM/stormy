import '../config/network_config.dart';
import '../error/network_exception.dart';

/// 响应字段解析器
/// 用于根据配置拆包外层格式，提取真实 data，或报错抛出业务异常。
class ResponseParser {
  /// 解包逻辑
  static dynamic decode(dynamic responseData, ResponseParsingConfig config) {
    if (responseData is! Map<String, dynamic>) {
      // 非标准包裹格式（如纯列表、字符串等），直接返回原数据
      return responseData;
    }

    // 检查是否存在 code 字段，如果连 code 都没有，说明可能没有遵循这套规范，也直接返回原数据
    if (!responseData.containsKey(config.codeKey)) {
      return responseData;
    }

    final code = responseData[config.codeKey];
    final message =
        responseData[config.messageKey]?.toString() ?? 'Unknown Error';
    final data = responseData[config.dataKey];

    // 判断成功条件 (兼容 Int 和 String)
    bool isSuccess = false;
    if (code == config.successCode) {
      isSuccess = true;
    } else if (code.toString() == config.successCode.toString()) {
      isSuccess = true;
    }

    if (isSuccess) {
      // 成功，直接返回内层 data
      return data;
    } else {
      // 捕获业务层定义的错误
      throw BusinessException(message, statusCode: _parseInt(code), data: data);
    }
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
