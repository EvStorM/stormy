import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';

class BaseImage extends StatefulWidget {
  const BaseImage({
    super.key,
    required this.url,
    this.width = double.infinity,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.baseColor = const Color(0xFFDEE6FD),
    this.highlightColor,
    this.noLoading = false,
    // 是否显示缩略图
    this.showThumbnail = false,
    // 自动高度模式 - 根据图片原始尺寸自动计算高度
    this.autoHeight = false,
    // 宽高比模式 - 根据宽高比计算高度
    this.aspectRatio,
  });

  /// 展示 assets 中的静态图片
  const BaseImage.asset(
    String assetPath, {
    super.key,
    this.width = double.infinity,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.baseColor = const Color(0xFFDEE6FD),
    this.highlightColor,
    this.noLoading = false,
    this.showThumbnail = false,
    this.autoHeight = false,
    this.aspectRatio,
  }) : url = assetPath;

  /// 展示文件系统中的静态图片
  BaseImage.file(
    File file, {
    super.key,
    this.width = double.infinity,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.baseColor = const Color(0xFFDEE6FD),
    this.highlightColor,
    this.noLoading = false,
    this.showThumbnail = false,
    this.autoHeight = false,
    this.aspectRatio,
  }) : url = file.path;

  final String url;
  final double width;
  final double? height;
  final double? maxWidth;
  final double? maxHeight;
  final BoxFit fit;
  final double radius;
  final Color? baseColor;
  final Color? highlightColor;
  final bool? noLoading;
  final bool showThumbnail;
  final bool autoHeight;
  final double? aspectRatio;

  @override
  State<BaseImage> createState() => _BaseImageState();
}

class _BaseImageState extends State<BaseImage> {
  // 计算实际显示尺寸，应用最大限制
  double _getConstrainedWidth() {
    if (widget.maxWidth == null) return widget.width;
    return min(widget.width, widget.maxWidth!);
  }

  double _getConstrainedHeight() {
    if (widget.maxHeight == null || widget.height == null)
      return widget.height ?? widget.width;
    return min(widget.height!, widget.maxHeight!);
  }

  @override
  Widget build(BuildContext context) {
    // 优先级：aspectRatio > autoHeight > 原有逻辑

    // 模式1：aspectRatio 模式 - 根据宽高比计算高度
    if (widget.aspectRatio != null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio!,
        child: _buildCachedImage(),
      );
    }

    // 模式2：autoHeight 模式 - 根据图片原始尺寸自动计算高度（仅支持网络图片）
    if (widget.autoHeight && widget.width != double.infinity) {
      // 检查是否为网络图片
      final isNetworkImage =
          !widget.url.startsWith('assets/') &&
          !widget.url.startsWith('packages/') &&
          !widget.url.startsWith('/') &&
          !widget.url.startsWith('file://');

      if (isNetworkImage) {
        return _AutoHeightImage(
          url: widget.url,
          width: _getConstrainedWidth(),
          fit: widget.fit,
          radius: widget.radius,
          baseColor: widget.baseColor,
          highlightColor: widget.highlightColor,
          noLoading: widget.noLoading,
          maxHeight: widget.maxHeight,
          showThumbnail: widget.showThumbnail,
        );
      }
    }

    // 原有逻辑
    return _buildCachedImage();
  }

  // 拼接缩略图
  String getThumbnailUrl(String url) {
    if (widget.showThumbnail) {
      final constrainedWidth = _getConstrainedWidth();
      // 向上取整，防止小数导致图片模糊
      final width = constrainedWidth.round() * 3;
      return '$url?x-oss-process=image/resize,m_lfit,w_${width.round()}/format,webp';
    }
    return url;
  }

  Widget _buildCachedImage() {
    final constrainedWidth = _getConstrainedWidth();
    final constrainedHeight = _getConstrainedHeight();

    // 判断图片来源类型
    if (widget.url.startsWith('assets/') ||
        widget.url.startsWith('packages/')) {
      // Assets 图片
      return Container(
        width: constrainedWidth,
        height: constrainedHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            widget.radius != 0 ? widget.radius : 0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            widget.radius != 0 ? widget.radius : 0,
          ),
          child: Image.asset(
            widget.url,
            width: constrainedWidth,
            height: constrainedHeight,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) => FadeShimmer(
              height: constrainedHeight,
              millisecondsDelay: 300,
              width: constrainedWidth,
              baseColor: widget.baseColor,
              highlightColor: widget.highlightColor ?? Colors.grey[100]!,
              radius: widget.radius != 0 ? widget.radius : 0,
            ),
          ),
        ),
      );
    } else if (widget.url.startsWith('/') || widget.url.startsWith('file://')) {
      // 文件系统图片
      final filePath = widget.url.startsWith('file://')
          ? widget.url.substring(7)
          : widget.url;
      return Container(
        width: constrainedWidth,
        height: constrainedHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            widget.radius != 0 ? widget.radius : 0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            widget.radius != 0 ? widget.radius : 0,
          ),
          child: Image.file(
            File(filePath),
            width: constrainedWidth,
            height: constrainedHeight,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) => FadeShimmer(
              height: constrainedHeight,
              millisecondsDelay: 300,
              width: constrainedWidth,
              baseColor: widget.baseColor,
              highlightColor: widget.highlightColor ?? Colors.grey[100]!,
              radius: widget.radius != 0 ? widget.radius : 0,
            ),
          ),
        ),
      );
    } else {
      // 网络图片
      return CachedNetworkImage(
        imageUrl: getThumbnailUrl(widget.url),
        imageBuilder: (context, imageProvider) => Container(
          width: constrainedWidth,
          height: constrainedHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              widget.radius != 0 ? widget.radius : 0,
            ),
            image: DecorationImage(image: imageProvider, fit: widget.fit),
          ),
        ),
        placeholder: (context, url) => widget.noLoading == true
            ? const SizedBox.shrink()
            : FadeShimmer(
                height: constrainedHeight,
                millisecondsDelay: 300,
                width: constrainedWidth,
                baseColor: widget.baseColor,
                highlightColor: widget.highlightColor ?? Colors.grey[100]!,
                radius: widget.radius != 0 ? widget.radius : 0,
              ),
        errorWidget: (context, url, error) => FadeShimmer(
          height: constrainedHeight,
          millisecondsDelay: 300,
          width: constrainedWidth,
          baseColor: widget.baseColor,
          highlightColor: widget.highlightColor ?? Colors.grey[100]!,
          radius: widget.radius != 0 ? widget.radius : 0,
        ),
        height: constrainedHeight,
        width: constrainedWidth,
        fit: widget.fit,
      );
    }
  }
}

/// 自动高度图片组件 - 根据图片原始尺寸计算高度
class _AutoHeightImage extends StatefulWidget {
  const _AutoHeightImage({
    required this.url,
    required this.width,
    required this.fit,
    required this.radius,
    required this.baseColor,
    required this.highlightColor,
    required this.noLoading,
    this.maxHeight,
    this.showThumbnail = false,
  });

  final String url;
  final double width;
  final BoxFit fit;
  final double radius;
  final Color? baseColor;
  final Color? highlightColor;
  final bool? noLoading;
  final double? maxHeight;
  final bool showThumbnail;

  @override
  State<_AutoHeightImage> createState() => _AutoHeightImageState();
}

class _AutoHeightImageState extends State<_AutoHeightImage> {
  double? _imageHeight;
  bool _isLoading = true;
  bool _isAutoHeight = true;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  String _getThumbnailUrl(String url) {
    if (widget.showThumbnail) {
      final width = widget.width.round() * 3;
      return '$url?x-oss-process=image/resize,m_lfit,w_${width.round()}/format,webp';
    }
    return url;
  }

  void _loadImageDimensions() {
    try {
      final imageUrl = _getThumbnailUrl(widget.url);
      final provider = CachedNetworkImageProvider(imageUrl);
      _imageStream = provider.resolve(ImageConfiguration.empty);

      _listener = ImageStreamListener((info, _) {
        final imageWidth = info.image.width.toDouble();
        final imageHeight = info.image.height.toDouble();
        bool isAutoHeight = _isAutoHeight;
        if (imageWidth > 0 && imageHeight > 0 && mounted) {
          double calculatedHeight = widget.width * (imageHeight / imageWidth);

          // 如果计算高度大于最大高度限制，则使用最大高度
          if (widget.maxHeight != null &&
              calculatedHeight > widget.maxHeight!) {
            calculatedHeight = widget.maxHeight!;
            isAutoHeight = false;
          }

          setState(() {
            _isAutoHeight = isAutoHeight;
            _imageHeight = calculatedHeight;
            _isLoading = false;
          });
          // 获取到尺寸后移除监听
          _imageStream?.removeListener(_listener!);
        }
      });

      _imageStream?.addListener(_listener!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _imageHeight = widget.width;
        });
      }
    }
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _imageHeight == null) {
      return FadeShimmer(
        height: widget.width,
        millisecondsDelay: 300,
        width: widget.width,
        baseColor: widget.baseColor,
        highlightColor: widget.highlightColor ?? Colors.grey[100]!,
        radius: widget.radius != 0 ? widget.radius : 0,
      );
    }

    return CachedNetworkImage(
      imageUrl: _getThumbnailUrl(widget.url),
      imageBuilder: (context, imageProvider) => Container(
        width: widget.width,
        height: _imageHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            widget.radius != 0 ? widget.radius : 0,
          ),
          image: DecorationImage(image: imageProvider, fit: widget.fit),
        ),
      ),
      placeholder: (context, url) => widget.noLoading == true
          ? const SizedBox.shrink()
          : FadeShimmer(
              height: _imageHeight ?? widget.width,
              millisecondsDelay: 300,
              width: widget.width,
              baseColor: widget.baseColor,
              highlightColor: widget.highlightColor ?? Colors.grey[100]!,
              radius: widget.radius != 0 ? widget.radius : 0,
            ),
      errorWidget: (context, url, error) => FadeShimmer(
        height: _imageHeight ?? widget.width,
        millisecondsDelay: 300,
        width: widget.width,
        baseColor: widget.baseColor,
        highlightColor: widget.highlightColor ?? Colors.grey[100]!,
        radius: widget.radius != 0 ? widget.radius : 0,
      ),
      height: _imageHeight,
      width: widget.width,
      fit: _isAutoHeight ? BoxFit.fitWidth : widget.fit,
      placeholderFadeInDuration: const Duration(milliseconds: 300),
    );
  }
}
