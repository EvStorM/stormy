import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'config_parser.dart';

class ParsedI18nData {
  final Map<String, String> translations;
  final String? description;
  final Map<String, dynamic>? placeholders;

  ParsedI18nData({
    required this.translations,
    this.description,
    this.placeholders,
  });
}

class DartParser {
  final StormyI18nConfig config;

  DartParser(this.config);

  /// 扫描源文件夹下的 dart 翻译文件，并剥离成 I18nItem 数据集
  Future<Map<String, ParsedI18nData>> parse() async {
    final dir = Directory(config.sourceDir);
    if (!dir.existsSync()) {
      return {};
    }

    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final result = <String, ParsedI18nData>{};

    for (var file in files) {
      final unit = parseFile(
        path: file.path,
        featureSet: FeatureSet.latestLanguageVersion(),
      ).unit;
      final visitor = _I18nVisitor();
      unit.accept(visitor);

      result.addAll(visitor.parsedItems);
    }

    return result;
  }
}

class _I18nVisitor extends RecursiveAstVisitor<void> {
  final Map<String, ParsedI18nData> parsedItems = {};
  String? _currentClassName;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _currentClassName = node.name.lexeme;
    super.visitClassDeclaration(node);
    _currentClassName = null;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (_currentClassName == null) {
      super.visitVariableDeclaration(node);
      return;
    }

    final init = node.initializer;
    String? typeName;
    ArgumentList? argumentList;

    if (init is InstanceCreationExpression) {
      typeName = init.constructorName.type.toSource();
      argumentList = init.argumentList;
    } else if (init is MethodInvocation) {
      typeName = init.methodName.name;
      argumentList = init.argumentList;
    }

    if (typeName == 'I18nItem' && argumentList != null) {
      final fieldName = node.name.lexeme;
      final map = <String, String>{};
      String? explicitKey;
      String? description;
      Map<String, dynamic>? placeholders;

      for (var arg in argumentList.arguments) {
        if (arg is NamedExpression) {
          final paramName = arg.name.label.name;
          final expr = arg.expression;

          if (paramName == 'key') {
            if (expr is StringLiteral) explicitKey = expr.stringValue;
          } else if (paramName == 'description') {
            if (expr is StringLiteral) description = expr.stringValue;
          } else if (paramName == 'placeholders') {
            if (expr is SetOrMapLiteral) {
              placeholders = _parsePlaceholders(expr);
            }
          } else {
            if (expr is StringLiteral) {
              map[paramName] = expr.stringValue ?? '';
            }
          }
        }
      }

      final inferredKey =
          explicitKey ?? _toSnakeCase('${_currentClassName}_$fieldName');
      parsedItems[inferredKey] = ParsedI18nData(
        translations: map,
        description: description,
        placeholders: placeholders,
      );
    }

    super.visitVariableDeclaration(node);
  }

  String _toSnakeCase(String text) {
    return text
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) {
          return '_${match.group(0)!.toLowerCase()}';
        })
        .replaceFirst(RegExp(r'^_'), '')
        .replaceAll('__', '_'); // 避免首字母大写导致的开头下划线
  }

  Map<String, dynamic> _parsePlaceholders(SetOrMapLiteral mapLiteral) {
    final result = <String, dynamic>{};
    for (var element in mapLiteral.elements) {
      if (element is MapLiteralEntry) {
        final keyExpr = element.key;
        final valueExpr = element.value;
        if (keyExpr is StringLiteral) {
          String? type;
          String? constructorName;
          ArgumentList? args;
          if (valueExpr is InstanceCreationExpression) {
            type = valueExpr.constructorName.type.toSource();
            constructorName = valueExpr.constructorName.name?.name;
            args = valueExpr.argumentList;
          } else if (valueExpr is MethodInvocation) {
            final targetStr = valueExpr.target?.toSource();
            if (targetStr == 'I18nPlaceholder') {
              type = 'I18nPlaceholder';
              constructorName = valueExpr.methodName.name;
              args = valueExpr.argumentList;
            } else {
              type = valueExpr.methodName.name;
              args = valueExpr.argumentList;
            }
          }

          if (type == 'I18nPlaceholder' && args != null) {
            result[keyExpr.stringValue!] = _parseI18nPlaceholderArgs(
              args,
              constructorName: constructorName,
            );
          }
        }
      }
    }
    return result;
  }

  Map<String, dynamic> _parseI18nPlaceholderArgs(
    ArgumentList argumentList, {
    String? constructorName,
  }) {
    final args = argumentList.arguments;
    final map = <String, dynamic>{};
    final optionalParams = <String, dynamic>{};

    if (constructorName != null) {
      if (constructorName == 'string') {
        map['type'] = 'String';
      } else if (constructorName == 'dateTime') {
        map['type'] = 'DateTime';
      } else if (constructorName.startsWith('int')) {
        map['type'] = 'int';
        if (constructorName.length > 3) {
          final formatName = constructorName.substring(
            3,
          ); // e.g., 'CompactCurrency'
          map['format'] = formatName[0].toLowerCase() + formatName.substring(1);
        }
      }
    } else {
      // First argument is positional (type)
      if (args.isNotEmpty) {
        final first = args.first;
        if (first is StringLiteral) {
          map['type'] = first.stringValue;
        }
      }
    }

    // Remaining arguments are named
    for (var arg in args) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        final valExpr = arg.expression;
        dynamic value;

        if (valExpr is StringLiteral) {
          value = valExpr.stringValue;
        } else if (valExpr is IntegerLiteral) {
          value = valExpr.value;
        } else if (valExpr is DoubleLiteral) {
          value = valExpr.value;
        } else if (valExpr is BooleanLiteral) {
          value = valExpr.value;
        } else if (valExpr is PrefixExpression &&
            valExpr.operator.lexeme == '-') {
          final operand = valExpr.operand;
          if (operand is IntegerLiteral) {
            final opValue = operand.value;
            if (opValue != null) value = -opValue;
          } else if (operand is DoubleLiteral) {
            value = -operand.value;
          }
        }

        if (value != null) {
          if (name == 'format' || name == 'customPattern') {
            map[name] = value;
          } else {
            optionalParams[name] = value;
          }
        } else if (name == 'optionalParameters' && valExpr is SetOrMapLiteral) {
          final parsedOpts = _parseOptionalParameters(valExpr);
          optionalParams.addAll(parsedOpts);
        }
      }
    }

    if (optionalParams.isNotEmpty) {
      map['optionalParameters'] = optionalParams;
    }
    return map;
  }

  Map<String, dynamic> _parseOptionalParameters(SetOrMapLiteral mapLiteral) {
    final result = <String, dynamic>{};
    for (var element in mapLiteral.elements) {
      if (element is MapLiteralEntry) {
        final keyExpr = element.key;
        final valExpr = element.value;
        if (keyExpr is StringLiteral) {
          if (valExpr is StringLiteral) {
            result[keyExpr.stringValue!] = valExpr.stringValue;
          } else if (valExpr is IntegerLiteral) {
            result[keyExpr.stringValue!] = valExpr.value;
          } else if (valExpr is DoubleLiteral) {
            result[keyExpr.stringValue!] = valExpr.value;
          } else if (valExpr is BooleanLiteral) {
            result[keyExpr.stringValue!] = valExpr.value;
          }
        }
      }
    }
    return result;
  }
}
