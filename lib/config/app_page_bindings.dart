import 'package:get/get.dart';

import '../controller/contact_intake_controller.dart';
import '../controller/event_controller.dart';
import '../controller/offre_controller.dart';
import '../controller/video_controller.dart';

class AdminDashboardBinding extends Bindings {
  @override
  void dependencies() {
    _registerRouteScoped<VideoController>(() => VideoController());
    _registerRouteScoped<OffreController>(() => OffreController());
    _registerRouteScoped<EventController>(() => EventController());
    _registerRouteScoped<ContactIntakeController>(
      () => ContactIntakeController(),
    );
  }

  void _registerRouteScoped<T>(T Function() builder) {
    if (Get.isRegistered<T>() || Get.isPrepared<T>()) {
      return;
    }

    Get.lazyPut<T>(builder);
  }
}
