// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class DialogDemoPage extends StatelessWidget {
  const DialogDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dialog Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBtn(context, 'Show Toast', () {
            SmartDialog.showToast('This is a toast message!');
          }),
          _buildBtn(context, 'Show Loading', () async {
            SmartDialog.showLoading(msg: 'Loading...');
            await Future.delayed(const Duration(seconds: 2));
            SmartDialog.dismiss();
          }),
          _buildBtn(context, 'Show Confirm Dialog', () {
            StormyDialog.instance.showConfirm(
              title: 'Confirm Action',
              message: 'Are you sure you want to perform this action?',
            ).then((value) {
               if (value == true) {
                 SmartDialog.showToast('Confirmed!');
               }
            });
          }),
          _buildBtn(context, 'Show Privacy Dialog', () {
             StormyStorage.instance.remove('stormy_privacy_agreed');
             StormyDialog.instance.showPrivacyDialog(
               context,
               onDone: () {
                 SmartDialog.showToast('Privacy Agreed!');
               },
             );
          }),
        ],
      ),
    );
  }

  Widget _buildBtn(BuildContext context, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: BaseButton(
        text: title,
        onPressed: onTap,
      ),
    );
  }
}
