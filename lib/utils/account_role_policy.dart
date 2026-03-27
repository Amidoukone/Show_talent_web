const List<String> publicSelfSignupRoles = ['joueur', 'fan'];
const List<String> managedAccountRoles = ['club', 'recruteur', 'agent'];
const List<String> opportunityPublisherRoles = ['club', 'recruteur', 'agent'];

const List<String> adminClaims = ['admin', 'platformAdmin', 'superAdmin'];

List<String> extractGrantedAdminClaims(Map<String, dynamic> claims) {
  return adminClaims.where((claim) => claims[claim] == true).toList();
}
