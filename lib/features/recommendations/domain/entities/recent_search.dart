/// Une recherche passée du client, telle que l'historique l'affiche : le
/// texte tapé, et la dernière fois qu'il l'a cherché.
///
/// Une seule entrée par texte, casse et accents confondus — c'est la base
/// qui dédoublonne (`fetch_recent_searches`, `0115`).
typedef RecentSearch = ({String query, DateTime searchedAt});
