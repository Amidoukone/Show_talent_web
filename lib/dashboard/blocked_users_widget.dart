import 'package:flutter/material.dart';

import 'user_management_widget.dart';

class BlockedUsersWidget extends StatelessWidget {
  const BlockedUsersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserManagementWidget(
      selectedRole: 'Tous',
      showBlockedUsers: true,
    );
  }
}
