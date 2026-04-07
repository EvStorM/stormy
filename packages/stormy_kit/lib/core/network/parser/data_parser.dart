import 'package:flutter/foundation.dart';

/// 统一解析器异常
class ParserException implements Exception {
  final String message;
  final dynamic rawData;
  final dynamic originalError;

  ParserException(
    this.message, {
    this.rawData,
    this.originalError,
  });

  @override
  String toString() => 'ParserException: $message';
}

/// 数据解析器抽象基础协议
/// 专门用于处理经过 ResponseParser 基础脱壳后（即抛弃了最外层 code、message 后）的纯净业务 Data。
abstract class DataParser<T> {
  T parse(dynamic rawBizData);
}

/// 直接透传解析器
/// 不进行任何映射，直接泛型强转。适用于外部不需要模型转换的快速开发场景。
class DirectParser<T> implements DataParser<T> {
  const DirectParser();

  @override
  T parse(dynamic rawBizData) {
    if (rawBizData is T) {
      return rawBizData;
    }
    return rawBizData as T;
  }
}

/// 标准 JSON 对象解析器
/// 用于解析 `{ "id": 1, "name": "foo" }` 格式的对象。
class JsonParser<T> implements DataParser<T> {
  final T Function(Map<String, dynamic> json) fromJson;
  final T Function(dynamic rawData)? fallbackParser;
  final bool debugMode;

  JsonParser(
    this.fromJson, {
    this.fallbackParser,
    this.debugMode = kDebugMode,
  });

  @override
  T parse(dynamic rawBizData) {
    if (rawBizData == null) {
      throw ParserException('返回的业务数据为空', rawData: rawBizData);
    }
    
    Map<String, dynamic> jsonMap;
    if (rawBizData is Map<String, dynamic>) {
      jsonMap = rawBizData;
    } else {
      if (fallbackParser != null) {
        return _tryFallback(rawBizData);
      }
      throw ParserException('返回的数据结构非 Map，期望 JSON 对象', rawData: rawBizData);
    }

    try {
      return fromJson(jsonMap);
    } catch (e) {
      if (fallbackParser != null) {
        return _tryFallback(rawBizData);
      }
      if (debugMode) {
        throw ParserException('JSON 解析构建失败: $e', rawData: rawBizData, originalError: e);
      }
      rethrow;
    }
  }

  T _tryFallback(dynamic rawBizData) {
    try {
      return fallbackParser!(rawBizData);
    } catch (fallbackError) {
      throw ParserException('降级解析失败: $fallbackError', rawData: rawBizData, originalError: fallbackError);
    }
  }
}

/// 标准 JSON 列表解析器
/// 用于解析 `[ { "id": 1 }, { "id": 2 } ]` 格式的列表。
class JsonListParser<T> implements DataParser<List<T>> {
  final T Function(Map<String, dynamic> json) itemFromJson;
  final T Function(dynamic itemData)? fallbackItemParser;
  final bool debugMode;

  JsonListParser(
    this.itemFromJson, {
    this.fallbackItemParser,
    this.debugMode = kDebugMode,
  });

  @override
  List<T> parse(dynamic rawBizData) {
    if (rawBizData == null) {
      return [];
    }

    if (rawBizData is! List) {
      throw ParserException('返回的数据结构非 List，期望 JSON 数组', rawData: rawBizData);
    }

    final List<T> results = [];
    for (final item in rawBizData) {
      if (item is Map<String, dynamic>) {
        try {
          results.add(itemFromJson(item));
        } catch (e) {
          _handleItemError(item, e, results);
        }
      } else {
        _handleItemError(item, ArgumentError("元素非 Map 对象"), results);
      }
    }
    return results;
  }

  void _handleItemError(dynamic item, Object error, List<T> results) {
    if (fallbackItemParser != null) {
      try {
        results.add(fallbackItemParser!(item));
      } catch (_) {
        if (debugMode) {
          throw ParserException('列表项解析及其降级处理均失败', rawData: item, originalError: error);
        }
      }
    } else {
      if (debugMode) {
        throw ParserException('列表项解析失败: $error', rawData: item, originalError: error);
      }
    }
  }
}

/// 分页元数据信息
class PaginationMeta {
  final int? currentPage;
  final int? pageSize;
  final int? total;
  final int? totalPages;
  final bool? hasNext;
  final bool? hasPrevious;

  PaginationMeta({
    this.currentPage,
    this.pageSize,
    this.total,
    this.totalPages,
    this.hasNext,
    this.hasPrevious,
  });

  factory PaginationMeta.empty() => PaginationMeta();
}

/// 分页包装结果
class PaginatedResult<T> {
  final List<T> data;
  final PaginationMeta meta;

  PaginatedResult(this.data, {required this.meta});
}

/// 标准分页列表解析器
/// 用于解析结构如：
/// `{ "list": [{...}, {...}], "page": 1, "total": 100 }`
/// 或
/// `{ "content": [{...}], "page": { "number": 1, "totalElements": 100 } }`
class JsonPageParser<T> implements DataParser<PaginatedResult<T>> {
  /// 承载列表数据的字段名称
  final String listFieldName;
  
  /// 分页信息嵌套的参数名，传 null 代表分页字段扁平化与列表同级
  final String? paginationObjName;

  /// 单个数据对象的解析函数
  final T Function(Map<String, dynamic> item) itemFromJson;

  /// 分页信息的字段映射表定义，允许对接完全不同的后端结构
  final Map<String, String> paginationFields;

  JsonPageParser(
    this.itemFromJson, {
    this.listFieldName = 'list',
    this.paginationObjName,
    Map<String, String>? paginationFields,
  }) : paginationFields = paginationFields ??
            {
              'currentPage': 'currentPage',
              'pageSize': 'pageSize',
              'total': 'total',
              'totalPages': 'totalPages',
              'hasNext': 'hasNext',
              'hasPrevious': 'hasPrevious',
            };

  @override
  PaginatedResult<T> parse(dynamic rawBizData) {
    if (rawBizData == null || rawBizData is! Map<String, dynamic>) {
      return PaginatedResult<T>([], meta: PaginationMeta.empty());
    }

    final listData = rawBizData[listFieldName];
    final List<T> results = [];
    if (listData is List) {
      for (final item in listData) {
        if (item is Map<String, dynamic>) {
          try {
            results.add(itemFromJson(item));
          } catch (_) {}
        }
      }
    }

    // 提取分页信息
    final Map<String, dynamic> sourceMap = paginationObjName != null 
        && rawBizData[paginationObjName] is Map<String, dynamic>
        ? rawBizData[paginationObjName] as Map<String, dynamic>
        : rawBizData;

    final meta = PaginationMeta(
      currentPage: sourceMap[paginationFields['currentPage']] as int?,
      pageSize: sourceMap[paginationFields['pageSize']] as int?,
      total: sourceMap[paginationFields['total']] as int?,
      totalPages: sourceMap[paginationFields['totalPages']] as int?,
      hasNext: sourceMap[paginationFields['hasNext']] as bool?,
      hasPrevious: sourceMap[paginationFields['hasPrevious']] as bool?,
    );

    return PaginatedResult<T>(results, meta: meta);
  }
}
