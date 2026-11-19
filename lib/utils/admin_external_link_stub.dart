/// L'implémentation hors web : il n'y a pas d'onglet à ouvrir.
library;

/// Toujours faux hors du web.
bool get adminExternalLinkSupported => false;

/// Ne fait rien hors du web, et le dit.
///
/// Rend `false` plutôt que de lever : l'appelant est une surface de
/// modération, et une revue de pièce doit pouvoir continuer — en recopiant
/// l'adresse à la main — là où aucun navigateur ne peut l'ouvrir.
bool openAdminExternalLink(String url) => false;
