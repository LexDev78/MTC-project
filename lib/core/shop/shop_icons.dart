import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Les icônes au trait du kit FlutterShop (`assets/icons/` du kit),
/// renommées à la mode du dépôt (`Arrow - Down.svg` → `arrow_down.svg`).
///
/// Le côté client n'utilise **que** celles-ci : mêler des icônes Material
/// pleines à ce jeu au trait suffit à faire paraître un écran inachevé.
abstract final class ShopIcons {
  static const _base = 'assets/shop/icons';

  static const accessories = '$_base/accessories.svg';
  static const address = '$_base/address.svg';
  static const arrowDown = '$_base/arrow_down.svg';
  static const arrowLeft = '$_base/arrow_left.svg';
  static const arrowRight = '$_base/arrow_right.svg';
  static const arrowUp = '$_base/arrow_up.svg';
  static const bag = '$_base/bag.svg';
  static const bagFull = '$_base/bag_full.svg';
  static const bookmark = '$_base/bookmark.svg';

  /// Le signet rempli : un article mis de côté. Absent du kit, tracé sur
  /// son propre signet.
  static const bookmarkFilled = '$_base/bookmark_filled.svg';

  static const calender = '$_base/calender.svg';
  static const call = '$_base/call.svg';
  static const cameraAdd = '$_base/camera_add.svg';
  static const cameraBold = '$_base/camera_bold.svg';
  static const card = '$_base/card.svg';
  static const cardPattern = '$_base/card_pattern.svg';
  static const cash = '$_base/cash.svg';
  static const category = '$_base/category.svg';
  static const chat = '$_base/chat.svg';
  static const chatAdd = '$_base/chat_add.svg';
  static const child = '$_base/child.svg';
  static const clock = '$_base/clock.svg';
  static const close = '$_base/close.svg';
  static const closeCircle = '$_base/close_circle.svg';
  static const coupon = '$_base/coupon.svg';
  static const cvv = '$_base/cvv.svg';
  static const dangerCircle = '$_base/danger_circle.svg';
  static const delete = '$_base/delete.svg';
  static const delivery = '$_base/delivery.svg';
  static const diamond = '$_base/diamond.svg';
  static const discount = '$_base/discount.svg';
  static const discountTag = '$_base/discount_tag.svg';
  static const dislike = '$_base/dislike.svg';
  static const dot = '$_base/dot.svg';
  static const dotsH = '$_base/dots_h.svg';
  static const dotsV = '$_base/dots_v.svg';
  static const doublecheck = '$_base/doublecheck.svg';
  static const editBold = '$_base/edit_bold.svg';
  static const editSquare = '$_base/edit_square.svg';
  static const emoji = '$_base/emoji.svg';
  static const faceId = '$_base/face_id.svg';
  static const faq = '$_base/faq.svg';
  static const filter = '$_base/filter.svg';
  static const fingerprint = '$_base/fingerprint.svg';
  static const flashlight = '$_base/flashlight.svg';
  static const gift = '$_base/gift.svg';
  static const help = '$_base/help.svg';
  static const image = '$_base/image.svg';
  static const info = '$_base/info.svg';
  static const language = '$_base/language.svg';
  static const like = '$_base/like.svg';
  static const link = '$_base/link.svg';
  static const loading = '$_base/loading.svg';
  static const location = '$_base/location.svg';
  static const lock = '$_base/lock.svg';
  static const logout = '$_base/logout.svg';
  static const man = '$_base/man.svg';
  static const manWoman = '$_base/man_woman.svg';
  static const message = '$_base/message.svg';
  static const miniDown = '$_base/mini_down.svg';
  static const miniLeft = '$_base/mini_left.svg';
  static const miniRight = '$_base/mini_right.svg';
  static const miniTop = '$_base/mini_top.svg';
  static const minus = '$_base/minus.svg';
  static const mylocation = '$_base/mylocation.svg';
  static const newcard = '$_base/newcard.svg';
  static const notification = '$_base/notification.svg';
  static const order = '$_base/order.svg';
  static const payonline = '$_base/payonline.svg';
  static const plus1 = '$_base/plus1.svg';
  static const preferences = '$_base/preferences.svg';
  static const product = '$_base/product.svg';
  static const profile = '$_base/profile.svg';
  static const returnBox = '$_base/return.svg';
  static const sale = '$_base/sale.svg';
  static const scan = '$_base/scan.svg';
  static const search = '$_base/search.svg';
  static const send = '$_base/send.svg';
  static const setting = '$_base/setting.svg';
  static const share = '$_base/share.svg';
  static const shop = '$_base/shop.svg';
  static const show = '$_base/show.svg';
  static const singlecheck = '$_base/singlecheck.svg';
  static const sizeguid = '$_base/sizeguid.svg';
  static const sort = '$_base/sort.svg';
  static const standard = '$_base/standard.svg';
  static const star = '$_base/star.svg';
  static const starBold = '$_base/star_bold.svg';
  static const starFilled = '$_base/star_filled.svg';
  static const stores = '$_base/stores.svg';
  static const trackorder = '$_base/trackorder.svg';
  static const wallet = '$_base/wallet.svg';
  static const wishlist = '$_base/wishlist.svg';
  static const woman = '$_base/woman.svg';
  static const worldMap = '$_base/world_map.svg';
}

/// Une icône du kit, teintée comme une `Icon` : par défaut la couleur de
/// l'`IconTheme` courant, donc juste en clair comme en sombre.
///
/// [tint] à `false` pour les rares icônes en couleur (l'étoile pleine, le
/// motif de carte), qui portent leurs propres teintes.
class ShopIcon extends StatelessWidget {
  const ShopIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.color,
    this.tint = true,
    this.semanticLabel,
  });

  final String asset;
  final double size;
  final Color? color;
  final bool tint;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final teinte =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: tint ? ColorFilter.mode(teinte, BlendMode.srcIn) : null,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
