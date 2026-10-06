import '../models/user.dart';

/// Apply the authoritative private snapshot, including removed fields.
void applyPrivateContact(AppUser user, Map<String, dynamic>? contact) {
  final email = contact?['email']?.toString().trim() ?? '';
  final phone = contact?['phone']?.toString().trim() ?? '';
  user.email = email.isEmpty ? 'Adresse e-mail inconnue' : email;
  user.phone = phone.isEmpty ? null : phone;
}
