import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../stormy_kit.dart' hide IsolateNameServer;

class H5 extends StatefulWidget with WidgetsBindingObserver {
  H5({
    super.key,
    required this.extra,
    this.title = '',
    this.url = '',
    this.nav = true,
    this.canRefresh = false,
    this.padding,
    this.hideProgress = false,
    this.forcedReturn = false,
    this.backgroundColor,
    this.appBarBgColor,
  });
  final Object? extra;
  String title;
  String url;
  bool nav;
  bool canRefresh;
  EdgeInsets? padding;
  Color? backgroundColor;
  Color? appBarBgColor;
  bool hideProgress;
  bool forcedReturn;
  static const String path = '/H5';
  @override
  State<H5> createState() => _H5State();
}

class _H5State extends State<H5> {
  InAppWebViewController? webViewController;
  InAppWebViewSettings options = InAppWebViewSettings(
    useOnDownloadStart: true,
    mediaPlaybackRequiresUserGesture: false,
    useShouldOverrideUrlLoading: true,
    javaScriptCanOpenWindowsAutomatically: true,
    allowFileAccessFromFileURLs: true,
    allowUniversalAccessFromFileURLs: true,
    allowsInlineMediaPlayback: true,
    useOnNavigationResponse: true,
    javaScriptEnabled: true,
    domStorageEnabled: true,
    databaseEnabled: true,
    cacheEnabled: true,
    clearCache: false,
    supportZoom: true,
    builtInZoomControls: false,
    displayZoomControls: false,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
  );
  double progress = 0;
  final ReceivePort _port = ReceivePort();
  Function(int)? downProgressCallback;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> map = widget.extra as Map<String, dynamic>;
    widget.title = map['title'] ?? '';
    widget.url = map['url'] ?? '';
    widget.nav = map['nav'] ?? true;
    widget.padding = map['padding'] ?? EdgeInsets.all(20.r);
    widget.forcedReturn = map['forcedReturn'] ?? false;
    widget.hideProgress = map['hideProgress'] ?? false;
    widget.backgroundColor =
        map['backgroundColor'] ?? StormyTheme.currentVariant.scaffoldBackground;
    widget.appBarBgColor =
        map['appBarBgColor'] ?? StormyTheme.currentVariant.scaffoldBackground;
    if (widget.url.isEmpty) {
      setState(() {
        _errorMessage = 'URL地址为空';
        _isLoading = false;
      });
      return;
    }

    if (!widget.url.startsWith('http://') &&
        !widget.url.startsWith('https://')) {
      setState(() {
        _errorMessage = 'URL格式无效';
        _isLoading = false;
      });
      return;
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      _bindBackgroundIsolate();
    });
  }

  @override
  void dispose() {
    _unbindBackgroundIsolate();
    super.dispose();
  }

  void _bindBackgroundIsolate() {
    final isSuccess = IsolateNameServer.registerPortWithName(
      _port.sendPort,
      'downloaderport',
    );
    if (!isSuccess) {
      _unbindBackgroundIsolate();
      _bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      final taskId = (data as List<dynamic>)[0] as String;
      final status = data[1];
      final progress = data[2] as int;
      if (status == 2) {
        downProgressCallback?.call(progress);
      } else if (status == 3) {
        SmartDialog.dismiss();
        SmartDialog.show(
          builder: (BuildContext context) {
            return Center(
              child: Container(
                width: 270.w,
                height: 100.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                child: Column(
                  children: [
                    SizedBox(height: 20.w),
                    Text(
                      'App下载完成',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            SmartDialog.dismiss();
                          },
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () async {
                            SmartDialog.dismiss();
                            // FlutterDownloader.open(taskId: taskId);
                          },
                          child: const Text('安装'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else if (status == 4) {
        SmartDialog.dismiss();
        SmartDialog.showToast('下载失败');
      }
    });
  }

  void _unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloaderport');
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    IsolateNameServer.lookupPortByName(
      'downloaderport',
    )?.send([id, status, progress]);
  }

  void _reloadPage() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    webViewController?.reload();
  }

  Widget _buildErrorPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 40.w, color: Colors.grey),
          SizedBox(height: 10.w),
          Text(
            _errorMessage ?? '页面加载失败',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 20.w),
          ElevatedButton(onPressed: _reloadPage, child: const Text('重新加载')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.nav
          ? AppBar(
              centerTitle: true,
              backgroundColor: widget.appBarBgColor,
              title: SizedBox(
                width: 240.w,
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              elevation: 0,
              leadingWidth: 60.w,
              actions: [
                if (widget.canRefresh)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _reloadPage,
                  )
                else
                  SizedBox(width: 60.w),
              ],
              leading: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.all(10.w),
                    child: GestureDetector(
                      onSecondaryTapUp: (details) {
                        Navigator.of(context).pop();
                      },
                      onTap: () async {
                        if (widget.forcedReturn) {
                          Navigator.pop(context);
                          return;
                        }
                        if (webViewController != null) {
                          final bool isBool = await webViewController!
                              .canGoBack();
                          if (isBool) {
                            webViewController!.goBack();
                          } else {
                            // ignore: use_build_context_synchronously
                            Navigator.pop(context);
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child:
                          (StormyConfigAccessor.assets?.backIcon.isNotEmpty ??
                              false)
                          ? Image.asset(
                              StormyConfigAccessor.assets!.backIcon,
                              width: 24.w,
                              height: 24.w,
                            )
                          : Icon(Icons.arrow_back_ios_new, size: 20.r),
                    ),
                  ),
                ],
              ),
            )
          : null,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: StormyTheme.currentVariant.scaffoldBackground,
            ),
            padding: widget.padding ?? StormyTheme.currentVariant.mainPadding,
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(widget.url)),
              initialSettings: options,
              onPermissionRequest: (controller, resources) async {
                return PermissionResponse(
                  resources: resources.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url!;

                if (uri.toString().startsWith('http://app.lanchou.vip')) {
                  Navigator.pop(context, true);
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              },
              onLoadStop: (controller, url) {
                setState(() {
                  _isLoading = false;
                });
              },
              onReceivedError: (controller, request, error) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = error.description;
                });
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'HTTP错误: ${errorResponse.statusCode}';
                });
              },
              onLoadResource: (controller, resource) {},
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onCreateWindow: (controller, createWindowRequest) async {
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: 400,
                        child: InAppWebView(
                          windowId: createWindowRequest.windowId,
                          onWebViewCreated:
                              (InAppWebViewController controller) {
                                webViewController = controller;
                              },
                        ),
                      ),
                    );
                  },
                );
                return true;
              },
              onNavigationResponse: (controller, navigationResponse) async {
                final name = navigationResponse.response?.suggestedFilename;
                if (name.isNotNullOrEmpty &&
                    name.toString().contains('mobileprovision')) {
                  // AppSettings.openAppSettings(
                  //     type: AppSettingsType.internalStorage);
                  return NavigationResponseAction.CANCEL;
                }
                return NavigationResponseAction.ALLOW;
              },
              onReceivedServerTrustAuthRequest: (controller, challenge) async {
                return ServerTrustAuthResponse(
                  action: ServerTrustAuthResponseAction.PROCEED,
                );
              },
              onProgressChanged: (controller, progressd) {
                if (mounted) {
                  setState(() {
                    progress = progressd / 100;
                  });
                }
              },
              onDownloadStartRequest:
                  (controller, DownloadStartRequest request) async {
                    if (Platform.isAndroid) {
                      await Permission.storage.request();

                      // final taskId = await FlutterDownloader.enqueue(
                      //   url: request.url.toString(),
                      //   savedDir: '/storage/emulated/0/Download',
                      //   saveInPublicStorage: true,
                      // );
                      // if (taskId != null) {
                      //   SmartDialog.show(
                      //     clickMaskDismiss: false,
                      //     alignment: Alignment.center,
                      //     builder: (_) => OtherTrick(
                      //       onUpdate: (onInvoke) =>
                      //           downProgressCallback = onInvoke,
                      //     ),
                      //   );
                      // }
                    } else if (Platform.isIOS) {}
                  },
            ),
          ),
          if (progress < 1.0 && _isLoading && widget.hideProgress == false)
            LinearProgressIndicator(
              value: progress,
              color: StormyTheme.currentVariant.secondary,
              backgroundColor: StormyTheme.currentVariant.background,
            )
          else
            Container(),
        ],
      ),
    );
  }
}
