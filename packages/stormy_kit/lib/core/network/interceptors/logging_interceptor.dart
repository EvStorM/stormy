import 'package:dio/dio.dart';
import 'package:stormy_kit/stormy_kit.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

import '../../../utils/tools/log_utils.dart'; // Import StormyLog

/// 日志拦截器工厂类
/// 封装 [TalkerDioLogger] 以便提供高颜值且符合项目规范的日志
class LoggingInterceptor {
  /// 构建一个 Talker 日志拦截器
  static Interceptor build({
    bool request = false,
    bool requestHeader = false,
    bool response = true,
    bool responseHeader = false,
    bool responseMessage = true,
    bool error = true,
  }) {
    return TalkerDioLogger(
      talker: StormyLog.talker,
      settings: TalkerDioLoggerSettings(
        // 请求打印设置
        printRequestHeaders: requestHeader,
        printRequestData: request,
        // 响应打印设置
        printResponseHeaders: responseHeader,
        printResponseMessage: responseMessage,
        printResponseData: response,
      ),
    );
  }
}
