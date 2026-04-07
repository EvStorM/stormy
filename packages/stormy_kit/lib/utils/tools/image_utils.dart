import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:stormy_kit/stormy_kit.dart';

/// 图片尺寸信息
class ImageSize {
  final int width;
  final int height;

  const ImageSize(this.width, this.height);

  @override
  String toString() => '${width}x$height';

  double get aspectRatio => width / height;
}

/// 缩略图输出格式
enum ThumbnailFormat {
  jpeg,
  png;

  String get extension {
    switch (this) {
      case ThumbnailFormat.jpeg:
        return '.jpg';
      case ThumbnailFormat.png:
        return '.png';
    }
  }

  Uint8List encode(img.Image image, {int quality = 80}) {
    switch (this) {
      case ThumbnailFormat.jpeg:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      case ThumbnailFormat.png:
        return Uint8List.fromList(img.encodePng(image));
    }
  }
}

/// 统一的图片操作结果包装器
///
/// 替代所有返回 `dynamic` / `null` 的旧设计。
/// 调用方通过 `result.isSuccess` 判断是否成功，
/// 成功时读取 `result.data`，失败时读取 `result.error`。
class ImageResult<T> {
  final T? data;
  final String? error;

  const ImageResult.success(this.data) : error = null;
  const ImageResult.failure(this.error) : data = null;

  bool get isSuccess => error == null;

  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    if (isSuccess) {
      return success(data as T);
    } else {
      return failure(error!);
    }
  }

  @override
  String toString() =>
      isSuccess ? 'ImageResult.success($data)' : 'ImageResult.failure($error)';
}

/// 图片处理器
///
/// 提供三个核心功能：
/// 1. 生成缩略图（支持本地文件、网络URL、字节数组）
/// 2. 获取图片宽高
/// 3. 保存图片到系统相册
///
/// 所有方法均通过 [ImageResult] 返回，不抛出异常。
class ImageUtils {
  ImageUtils._();

  // ─────────────────────────────────────────────────────────────────
  //  公开 API：缩略图
  // ─────────────────────────────────────────────────────────────────

  /// 生成缩略图
  ///
  /// [source] 图片来源，支持：
  /// - `String`：本地文件路径或网络 URL（以 `http://` 或 `https://` 开头）
  /// - `Uint8List`：原始字节数据
  ///
  /// [maxWidth] 最大宽度（像素），默认 150
  /// [maxHeight] 最大高度（像素），默认 150
  /// [quality] JPEG 压缩质量（1-100），默认 80；PNG/WebP 忽略此参数
  /// [format] 输出格式，默认 `ThumbnailFormat.jpeg`
  /// [cacheDir] 自定义缓存目录，默认使用系统临时目录/thumbnails
  ///
  /// 返回 `ImageResult<Uint8List>`，data 为缩略图字节数据。
  ///
  /// 内部实现自动对相同参数生成的缩略图进行缓存（缓存目录内文件名含参数哈希），
  /// 缓存命中时跳过解码直接返回。
  static Future<ImageResult<Uint8List>> generateThumbnail(
    dynamic source, {
    int maxWidth = 150,
    int maxHeight = 150,
    int quality = 80,
    ThumbnailFormat format = ThumbnailFormat.jpeg,
    String? cacheDir,
  }) async {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const ImageResult.failure('maxWidth 和 maxHeight 必须大于 0');
    }
    if (source == null) {
      return const ImageResult.failure('source 不能为空');
    }

    try {
      // 生成缓存 key，检查缓存
      final key = _cacheKey(source, maxWidth, maxHeight, quality, format);
      final cachePath = await _getCacheFilePath(key, cacheDir: cacheDir);
      final cacheFile = File(cachePath);

      if (await _isCacheValid(cacheFile)) {
        return ImageResult.success(await cacheFile.readAsBytes());
      }

      // 获取原始字节
      final bytes = await _fetchBytes(source);

      // 解码并缩放
      final thumbnailBytes = _generateThumbnailBytes(
        bytes,
        maxWidth,
        maxHeight,
        quality,
        format,
      );

      // 写入缓存
      await cacheFile.writeAsBytes(thumbnailBytes);

      return ImageResult.success(thumbnailBytes);
    } catch (e) {
      return ImageResult.failure(e.toString());
    }
  }

  /// 生成缩略图并保存到指定路径
  ///
  /// [source] 同 [generateThumbnail]
  /// [savePath] 完整的保存路径（含文件名和扩展名），由调用方保证目录存在
  /// 其余参数同 [generateThumbnail]
  ///
  /// 返回 `ImageResult<String>`，data 为保存的文件路径。
  static Future<ImageResult<String>> generateThumbnailAndSave(
    dynamic source,
    String savePath, {
    int maxWidth = 150,
    int maxHeight = 150,
    int quality = 80,
    ThumbnailFormat format = ThumbnailFormat.jpeg,
  }) async {
    final result = await generateThumbnail(
      source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
      format: format,
    );

    if (!result.isSuccess) {
      return ImageResult.failure(result.error!);
    }

    try {
      final outFile = File(savePath);
      final outDir = outFile.parent;
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      await outFile.writeAsBytes(result.data!);
      return ImageResult.success(savePath);
    } catch (e) {
      return ImageResult.failure('写入文件失败: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  公开 API：获取图片宽高
  // ─────────────────────────────────────────────────────────────────

  /// 从字节数组获取图片宽高
  ///
  /// 解码仅读取头部信息，不完全解码图片，内存开销极小。
  static Future<ImageResult<ImageSize>> getImageSizeFromBytes(
    Uint8List bytes,
  ) async {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return const ImageResult.failure('无法解码图片数据');
      }
      return ImageResult.success(ImageSize(decoded.width, decoded.height));
    } catch (e) {
      return ImageResult.failure(e.toString());
    }
  }

  /// 从文件路径或网络 URL 获取图片宽高
  ///
  /// 自动判断：如果字符串以 `http://` 或 `https://` 开头则下载后读取，
  /// 否则作为本地文件路径读取。
  static Future<ImageResult<ImageSize>> getImageSize(String path) async {
    try {
      final bytes = await _fetchBytes(path);
      return getImageSizeFromBytes(bytes);
    } catch (e) {
      return ImageResult.failure(e.toString());
    }
  }

  /// 从 Asset 资源路径获取图片宽高
  ///
  /// 使用 [ServicesBinding.rootBundle] 加载资源。
  static Future<ImageResult<ImageSize>> getImageSizeFromAsset(
    String assetPath,
  ) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      return getImageSizeFromBytes(bytes);
    } catch (e) {
      return ImageResult.failure(e.toString());
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  公开 API：保存到相册
  // ─────────────────────────────────────────────────────────────────

  /// 将图片保存到系统相册
  ///
  /// [source] 图片来源，支持：
  /// - `String`：本地文件路径或网络 URL
  /// - `Uint8List`：原始字节数据
  /// - `XFile`：来自 image_picker 等平台插件的文件对象
  ///
  /// [album] 相册名称；相册不存在时由系统自动创建。
  /// iOS 会创建以 [album] 命名的相册，Android 行为取决于系统版本。
  ///
  /// 返回 `ImageResult<String>`，data 为相册中保存的文件路径。
  static Future<ImageResult<String>> saveToGallery(
    dynamic source, {
    String album = 'App Photos',
  }) async {
    if (source == null) {
      return const ImageResult.failure('source 不能为空');
    }

    try {
      String filePath;

      if (source is String) {
        if (source.startsWith('http://') || source.startsWith('https://')) {
          // 网络 URL：下载到临时文件
          final tmpDir = await getTemporaryDirectory();
          final urlHash = md5.convert(source.codeUnits).toString();
          final tmpPath = '${tmpDir.path}/gal_tmp_$urlHash.jpg';
          await Dio().download(source, tmpPath);
          filePath = tmpPath;
        } else {
          filePath = source;
        }
      } else if (source is Uint8List) {
        final tmpDir = await getTemporaryDirectory();
        final tmpPath =
            '${tmpDir.path}/gal_tmp_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(tmpPath).writeAsBytes(source);
        filePath = tmpPath;
      } else if (source is XFile) {
        filePath = source.path;
      } else {
        return const ImageResult.failure('不支持的 source 类型');
      }

      // 写入相册
      await Gal.putImage(filePath, album: album);

      return ImageResult.success(filePath);
    } catch (e) {
      return ImageResult.failure(e.toString());
    }
  }

  /// 请求相册写入权限（Android 13+ / iOS）
  ///
  /// Android 12 及以下、iOS 较老版本无需请求，系统自动授权。
  /// 返回 `ImageResult<bool>`：
  /// - `isSuccess == true` 且 `data == true`：已授权
  /// - `isSuccess == true` 且 `data == false`：拒绝授权
  /// - `isSuccess == false`：请求过程中发生异常
  static Future<ImageResult<bool>> requestGalleryPermission() async {
    try {
      final granted = await Gal.requestAccess(toAlbum: true);
      return ImageResult.success(granted);
    } catch (e) {
      return ImageResult.failure(e.toString());
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  私有辅助方法
  // ─────────────────────────────────────────────────────────────────

  /// 统一获取字节数据：支持 String(本地/网络) / Uint8List / XFile
  static Future<Uint8List> _fetchBytes(dynamic source) async {
    if (source is String) {
      if (source.startsWith('http://') || source.startsWith('https://')) {
        final response = await Dio().get<List<int>>(
          source,
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(response.data!);
      } else {
        final file = File(source);
        if (!await file.exists()) {
          throw Exception('文件不存在: $source');
        }
        return await file.readAsBytes();
      }
    } else if (source is Uint8List) {
      return source;
    } else if (source is XFile) {
      return await source.readAsBytes();
    } else {
      throw Exception('不支持的 source 类型: ${source.runtimeType}');
    }
  }

  /// 使用 image 包生成缩略图字节
  static Uint8List _generateThumbnailBytes(
    Uint8List bytes,
    int maxWidth,
    int maxHeight,
    int quality,
    ThumbnailFormat format,
  ) {
    final src = img.decodeImage(bytes);
    if (src == null) {
      throw Exception('无法解码图片数据');
    }

    // 计算保持宽高比的缩放目标尺寸
    final scaleX = maxWidth / src.width;
    final scaleY = maxHeight / src.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final clampedScale = scale > 1.0 ? 1.0 : scale;

    final targetWidth = (src.width * clampedScale).round();
    final targetHeight = (src.height * clampedScale).round();

    final thumbnail = img.copyResize(
      src,
      width: targetWidth,
      height: targetHeight,
    );

    return format.encode(thumbnail, quality: quality);
  }

  /// 获取缓存目录下的文件路径
  static Future<String> _getCacheFilePath(
    String key, {
    String? cacheDir,
  }) async {
    final baseDir = cacheDir ?? (await getTemporaryDirectory()).path;
    final cacheDirObj = Directory('$baseDir/thumbnails');
    if (!await cacheDirObj.exists()) {
      await cacheDirObj.create(recursive: true);
    }
    return '${cacheDirObj.path}/thumb_$key';
  }

  /// 生成缓存 key：对 source 内容+尺寸参数取 MD5 前 32 位
  static String _cacheKey(
    dynamic source,
    int maxWidth,
    int maxHeight,
    int quality,
    ThumbnailFormat format,
  ) {
    String sourceId;
    if (source is String) {
      sourceId = source;
    } else if (source is Uint8List) {
      sourceId = '${source.length}_${source.hashCode}';
    } else if (source is XFile) {
      sourceId = '${source.path}_${source.length()}';
    } else {
      sourceId = source.toString();
    }

    final raw = '$sourceId\_$maxWidth\_$maxHeight\_$quality\_${format.name}';
    final digest = md5.convert(raw.codeUnits);
    return digest.toString();
  }

  /// 检查缓存文件是否有效：存在且大于 1KB
  static Future<bool> _isCacheValid(File file) async {
    try {
      if (!await file.exists()) return false;
      final length = await file.length();
      return length > 1024;
    } catch (_) {
      return false;
    }
  }
}
