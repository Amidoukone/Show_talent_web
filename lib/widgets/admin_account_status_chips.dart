import 'package:flutter/material.dart';

import '../models/user.dart';

class AdminAccountStatusChips extends StatelessWidget {
  const AdminAccountStatusChips({
    required this.user,
    super.key,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final statuses = <_StatusItem>[];

    if (user.estBloque) {
      statuses.add(const _StatusItem(
        label: 'bloque',
        backgroundColor: Color(0xFFF8D7DA),
        textColor: Color(0xFF8A1C28),
      ));
    }

    if (user.authDisabled) {
      statuses.add(const _StatusItem(
        label: 'auth desactive',
        backgroundColor: Color(0xFFFFE5B4),
        textColor: Color(0xFF8A5A00),
      ));
    }

    if (!user.estActif) {
      statuses.add(const _StatusItem(
        label: 'inactif',
        backgroundColor: Color(0xFFE2E3E5),
        textColor: Color(0xFF495057),
      ));
    }

    if (statuses.isEmpty) {
      statuses.add(const _StatusItem(
        label: 'actif',
        backgroundColor: Color(0xFFDFF3E4),
        textColor: Color(0xFF1E6B35),
      ));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: statuses.map((status) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: status.backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              color: status.textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatusItem {
  const _StatusItem({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
}
