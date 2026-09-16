import 'core/network/stormy_network.dart';

/// Optional default services; applications can also own independent clients.
class StormyServices {
  StormyServices._();
  static StormyNetworkClient? networkClient;
  static void reset() {
    networkClient?.dio.close(force: true);
    networkClient = null;
  }
}
