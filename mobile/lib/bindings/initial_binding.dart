import 'package:get/get.dart';

import '../data/datasources/audio_api_client.dart';
import '../data/repositories/audio_repository.dart';
import '../presentation/controllers/dashboard_controller.dart';

/// Registers global dependencies for GetX.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<AudioApiClient>(AudioApiClient(), permanent: true);
    Get.put<AudioRepository>(
      AudioRepository(client: Get.find<AudioApiClient>()),
      permanent: true,
    );
    Get.lazyPut<DashboardController>(() => DashboardController());
  }
}
