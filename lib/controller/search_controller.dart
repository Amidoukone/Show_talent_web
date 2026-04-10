import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/offre.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/utils/account_role_policy.dart';

class CustomSearchController extends GetxController {
  final RxList<AppUser> _searchedUsers = <AppUser>[].obs;
  List<AppUser> get searchedUsers => _searchedUsers;

  final RxList<Offre> _searchedOffres = <Offre>[].obs;
  List<Offre> get searchedOffres => _searchedOffres;

  Future<void> search(
    String query, {
    String? role,
    String? location,
  }) async {
    Query<Map<String, dynamic>> userQuery =
        FirebaseFirestore.instance.collection('users');

    final normalizedQuery = query.trim();
    final normalizedRole = normalizeUserRole(role);
    final normalizedLocation = location?.trim() ?? '';

    if (normalizedQuery.isNotEmpty) {
      userQuery = userQuery
          .where('nom', isGreaterThanOrEqualTo: normalizedQuery)
          .where('nom', isLessThanOrEqualTo: '$normalizedQuery\uf8ff');
    }

    final userSnapshot = await userQuery.get();
    final users = userSnapshot.docs
        .map((doc) => AppUser.fromMap(doc.data()))
        .where((user) {
      final matchesRole = normalizedRole.isEmpty ||
          normalizeUserRole(user.role) == normalizedRole;
      final matchesLocation = normalizedLocation.isEmpty ||
          user.matchesLocation(normalizedLocation);
      return matchesRole && matchesLocation;
    }).toList();

    _searchedUsers.assignAll(users);
  }

  Future<void> searchOffres(
    String query, {
    String? category,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query offreQuery = FirebaseFirestore.instance.collection('offres');

    if (category != null && category.isNotEmpty) {
      offreQuery = offreQuery.where('category', isEqualTo: category);
    }

    if (startDate != null && endDate != null) {
      offreQuery = offreQuery
          .where('dateDebut', isGreaterThanOrEqualTo: startDate)
          .where('dateFin', isLessThanOrEqualTo: endDate);
    }

    if (query.isNotEmpty) {
      offreQuery = offreQuery
          .where('titre', isGreaterThanOrEqualTo: query)
          .where('titre', isLessThanOrEqualTo: '$query\uf8ff');
    }

    final offreSnapshot = await offreQuery.get();
    _searchedOffres.assignAll(
      offreSnapshot.docs
          .map((doc) => Offre.fromMap(doc.data() as Map<String, dynamic>))
          .toList(),
    );
  }
}
