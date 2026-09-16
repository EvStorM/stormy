import 'dart:convert';
import 'dart:io';
import 'package:stormy_store_pay/stormy_store_pay.dart';

/// 后端负责联系商店验证凭证、绑定登录用户并幂等发放权益。
/// 运行时通过 --dart-define=PURCHASE_VERIFICATION_URL=https://... 指定服务。
/// 宿主应在此接入自己的登录会话；不要在客户端保存服务端商店密钥。
Future<bool> verifyReceipt(PurchaseDetails purchase) async {
  const endpoint = String.fromEnvironment('PURCHASE_VERIFICATION_URL');
  final uri = Uri.tryParse(endpoint);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw StateError('请配置 HTTPS PURCHASE_VERIFICATION_URL 后端验单地址');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'source': purchase.verificationData.source,
        'receipt': purchase.verificationData.serverVerificationData,
      }),
    );
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) return false;
    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 30));
    final result = jsonDecode(body);
    return result is Map<String, dynamic> && result['verified'] == true;
  } finally {
    client.close(force: true);
  }
}
