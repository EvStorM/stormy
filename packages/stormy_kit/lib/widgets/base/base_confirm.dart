import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

import '../../../stormy_kit.dart';

class BaseConfirm extends StatelessWidget {
  const BaseConfirm({
    super.key,
    required this.title,
    required this.content,
    required this.onCancel,
    required this.onConfirm,
    this.cancelText = '取消',
    this.confirmText = '确认',
  });

  final String title;
  final String content;
  final Function()? onCancel;
  final Function()? onConfirm;
  final String cancelText;
  final String confirmText;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: MediaQuery.of(context).size.width * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(16.r)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20.r),
              child: Column(
                children: [
                  SizedBox(height: 18.r),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18.r,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.r),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          content,
                          style: TextStyle(
                            fontSize: 14.r,
                            color: StormyTheme.currentVariant.contentText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.r),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 140.r,
                        height: 48.r,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: const Color(0xfff6f6f6),
                          borderRadius: BorderRadius.circular(4.r),
                          child: Text(
                            cancelText,
                            style: TextStyle(
                              fontSize: 16.r,
                              fontWeight: FontWeight.w700,
                              color: StormyTheme.currentVariant.bodyText,
                            ),
                          ),
                          onPressed: () {
                            onCancel?.call();
                            SmartDialog.dismiss(result: false);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 140.r,
                        height: 48.r,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: StormyTheme.currentVariant.primary,
                          borderRadius: BorderRadius.circular(4.r),
                          child: Text(
                            confirmText,
                            style: TextStyle(
                              fontSize: 16.r,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: () {
                            onConfirm?.call();
                            SmartDialog.dismiss(result: true);
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> baseShowConfirm(
  String title,
  String content,
  Function()? onCancel,
  Function()? onConfirm,
) async {
  return await SmartDialog.show(
    builder: (context) => BaseConfirm(
      title: title,
      content: content,
      onCancel: onCancel,
      onConfirm: onConfirm,
    ),
  );
}
