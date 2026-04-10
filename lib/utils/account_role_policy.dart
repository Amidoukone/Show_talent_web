const List<String> publicSelfSignupRoles = ['joueur', 'fan'];
const List<String> managedAccountRoles = ['club', 'recruteur', 'agent'];
const List<String> opportunityPublisherRoles = ['club', 'recruteur', 'agent'];
const List<String> adminPortalOnlyRoles = ['admin'];

const List<String> adminClaims = ['admin', 'platformAdmin', 'superAdmin'];

String normalizeUserRole(String? role) => role?.trim().toLowerCase() ?? '';

bool isPublicSelfSignupRole(String? role) {
  return publicSelfSignupRoles.contains(normalizeUserRole(role));
}

bool isManagedAccountRole(String? role) {
  return managedAccountRoles.contains(normalizeUserRole(role));
}

bool isOpportunityPublisherRole(String? role) {
  return opportunityPublisherRoles.contains(normalizeUserRole(role));
}

bool isAdminPortalOnlyRole(String? role) {
  return adminPortalOnlyRoles.contains(normalizeUserRole(role));
}

List<String> extractGrantedAdminClaims(Map<String, dynamic> claims) {
  return adminClaims.where((claim) => claims[claim] == true).toList();
}
