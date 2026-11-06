/// Les noms qu'on ne porte pas : ceux qui se font passer pour MTC.
///
/// Miroir de `is_reserved_public_name` (`0144`), qui tranche côté base —
/// à l'inscription, GoTrue ne rend qu'une erreur générique quand la base
/// refuse, d'où ce contrôle anticipé pour un message clair. Même table de
/// lettres sosies que la base (générée ensemble), mêmes caractères
/// invisibles retirés, mêmes règles. Seule différence : la base passe
/// d'abord le nom en forme NFKC (lettres mathématiques « 𝐌𝐓𝐂 », chiffres
/// romains « ⅿ »), que Dart ne sait pas faire sans dépendance — ces
/// graphies-là sont refusées par la base seule.
library;

const _lettres = 'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎďĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľŃńŅņŇňŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžſƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǞǟǠǡǦǧǨǩǪǫǬǭǰǴǵǸǹǺǻȀȁȂȃȄȅȆȇȈȉȊȋȌȍȎȏȐȑȒȓȔȕȖȗȘșȚțȞȟȦȧȨȩȪȫȬȭȮȯȰȱȲȳḀḁḂḃḄḅḆḇḈḉḊḋḌḍḎḏḐḑḒḓḔḕḖḗḘḙḚḛḜḝḞḟḠḡḢḣḤḥḦḧḨḩḪḫḬḭḮḯḰḱḲḳḴḵḶḷḸḹḺḻḼḽḾḿṀṁṂṃṄṅṆṇṈṉṊṋṌṍṎṏṐṑṒṓṔṕṖṗṘṙṚṛṜṝṞṟṠṡṢṣṤṥṦṧṨṩṪṫṬṭṮṯṰṱṲṳṴṵṶṷṸṹṺṻṼṽṾṿẀẁẂẃẄẅẆẇẈẉẊẋẌẍẎẏẐẑẒẓẔẕẖẗẘẙẛẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹABCDEFGHIJKLMNOPQRSTUVWXYZАВЕКМНОРСТУХаеорсухмтквнΑΒΕΗΙΚΜΝΟΡΤΥΧαεικνορτυχ０１２３４５６７８９ＡａＢｂＣｃＤｄＥｅＦｆＧｇＨｈＩｉＪｊＫｋＬｌＭｍＮｎＯｏＰｐＱｑＲｒＳｓＴｔＵｕＶｖＷｗＸｘＹｙＺｚᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘʀꜱᴛᴜᴠᴡʏᴢЅѕІіЈјԀԁҺһԚԛԜԝӀӏҮүҒԍԌƖϲϹϳͿςΖζϐϻϺıȷɑɡɩʋɯʍꞵ';
const _equivalents = 'aaaaaaceeeeiiiinooooouuuuyaaaaaaceeeeiiiinooooouuuuyyaaaaaaccccccccddeeeeeeeeeegggggggghhiiiiiiiiijjkkllllllnnnnnnoooooorrrrrrssssssssttttuuuuuuuuuuuuwwyyyzzzzzzsoouuaaiioouuuuuuuuuuaaaaggkkoooojggnnaaaaaaeeeeiiiioooorrrruuuusstthhaaeeooooooooyyaabbbbbbccddddddddddeeeeeeeeeeffgghhhhhhhhhhiiiikkkkkkllllllllmmmmmmnnnnnnnnoooooooopppprrrrrrrrssssssssssttttttttuuuuuuuuuuvvvvwwwwwwwwwwxxxxyyzzzzzzhtwysaaaaaaaaaaaaaaaaaaaaaaaaeeeeeeeeeeeeeeeeiiiioooooooooooooooooooooooouuuuuuuuuuuuuuyyyyyyyyabcdefghijklmnopqrstuvwxyzabekmhopctyxaeopcyxmtkbhabehikmnoptyxaeiknoptux0123456789aabbccddeeffgghhiijjkkllmmnnooppqqrrssttuuvvwwxxyyzzabcdefghijklmnoprstuvwyzssiijjddhhqqwwllyyfgglccjjczzbmmijagiumwb';

final Map<int, String> _table = {
  for (var i = 0; i < _lettres.runes.length; i++)
    _lettres.runes.elementAt(i): String.fromCharCode(_equivalents.runes.elementAt(i)),
};

/// Invisibles (largeur nulle, direction, trait d'union conditionnel,
/// sélecteurs de variante) et diacritiques combinants : la même liste que
/// la base.
final _invisibles = RegExp(
  '[\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180E\u200B-\u200F'
  '\u202A-\u202E\u2060-\u206F\u3164\uFE00-\uFE0F\uFEFF\uFFA0'
  '\u0300-\u036F\u1AB0-\u1AFF\u1DC0-\u1DFF\u20D0-\u20FF\uFE20-\uFE2F]',
);

/// « M.T.C Officiel » → « mtc officiel » : minuscules sans accents, mots
/// séparés par une espace, lettres isolées qui se suivent recollées (la même
/// expression que la base : une lettre seule suivie d'une autre lettre
/// seule). « Karim T. Coulibaly » reste « karim t coulibaly ».
String normalizedPublicName(String name) {
  final sansInvisibles = name.toLowerCase().replaceAll(_invisibles, '');
  final buffer = StringBuffer();
  for (final rune in sansInvisibles.runes) {
    buffer.write(_table[rune] ?? String.fromCharCode(rune));
  }
  final espace = buffer.toString().replaceAll(RegExp('[^a-z0-9]+'), ' ');
  return espace
      .replaceAllMapped(RegExp(r'\b([a-z]) (?=[a-z]\b)'), (m) => m[1]!)
      .trim();
}

const _motsReserves = {
  'admin', 'administrateur', 'administratrice', 'administration',
  'support', 'staff', 'moderateur', 'moderatrice', 'moderation',
  'equipe', 'service', 'serviceclient', 'servicesclients',
  'serviceclientele', 'supportclient', 'assistance',
};

bool isReservedPublicName(String name) {
  final normalise = normalizedPublicName(name);
  final mots = normalise.split(' ').where((m) => m.isNotEmpty).toList();
  final colle = normalise.replaceAll(' ', '');
  // Un mot qui contient « mtc » (« rn » compté pour « m », qui s'y confond).
  if (mots.any((m) => m.contains('mtc') || m.replaceAll('rn', 'm').contains('mtc'))) {
    return true;
  }
  // Quelques mots voisins qui, recollés, commencent par « mtc » : « M TC ».
  for (var i = 0; i < mots.length; i++) {
    if (!const {'m', 'mt', 'rn', 'rnt'}.contains(mots[i])) continue;
    final suite = mots.skip(i).take(3).join().replaceAll('rn', 'm');
    if (suite.startsWith('mtc')) return true;
  }
  return colle.contains('tradeconnect') ||
      _motsReserves.contains(colle) ||
      colle.startsWith('serviceclient') ||
      colle.startsWith('supportclient') ||
      colle.startsWith('supporttechnique') ||
      colle.startsWith('administrat');
}
