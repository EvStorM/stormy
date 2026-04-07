import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

class WidgetsDemoPage extends StatefulWidget {
  const WidgetsDemoPage({super.key});

  @override
  State<WidgetsDemoPage> createState() => _WidgetsDemoPageState();
}

class _WidgetsDemoPageState extends State<WidgetsDemoPage> {
  bool _isChecked = false;
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      appBar: AppBar(
        title: const Text('Widgets Demo'),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('BaseButton',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          BaseButton(text: 'I am BaseButton', onPressed: () {}),
          const SizedBox(height: 24),
          const Text('BaseInput',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          BaseInput(
            controller: _inputController,
            hintText: 'I am BaseInput',
          ),
          const SizedBox(height: 24),
          const Text('AgreementWidget',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AgreementWidget(
            isChecked: _isChecked,
            onChanged: (value) {
              setState(() {
                _isChecked = value;
              });
            },
            iconSize: 14.0,
            spacing: 2.0,
            segments: [
              const TextSegment('我已阅读并接受'),
              ProtocolSegment(
                AgreeItemModel(label: '《用户协议》', agreeUrl: '...'),
              ),
              const TextSegment('以及'),
              ProtocolSegment(
                AgreeItemModel(label: '《隐私政策》', agreeUrl: '...'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
