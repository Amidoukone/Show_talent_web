import 'package:get/get.dart';

import '../controller/auth_controller.dart';
import '../controller/user_controller.dart';

class AppBindings {
  AppBindings._();

  static void registerPermanentDependencies() {
    _registerPermanent<UserController>(() => UserController());
    _registerPermanent<AuthController>(() => AuthController());
  }

  static T _registerPermanent<T>(T Function() builder) {
    if (Get.isRegistered<T>()) {
      return Get.find<T>();
    }

    return Get.put<T>(builder(), permanent: true);
  }
}
