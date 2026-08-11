import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_colors.dart';
import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';

class _HeroSlide {
  const _HeroSlide({
    required this.image,
    required this.headline,
    required this.cta,
  });

  final String image;
  final String headline;
  final String cta;
}

const _slides = [
  _HeroSlide(
    image: 'assets/images/products/textiles/fabric.jpg',
    headline: 'Le meilleur du Mali,\nlivré chez vous',
    cta: 'Découvrir',
  ),
  _HeroSlide(
    image: 'assets/images/products/artisanat/mask.jpg',
    headline: 'Artisanat authentique,\nfait main',
    cta: 'Explorer',
  ),
  _HeroSlide(
    image: 'assets/images/products/electronique/solar_panel.jpg',
    headline: 'MTC Officiel,\nqualité garantie',
    cta: 'Voir plus',
  ),
];

/// Gradient promo carousel shown atop the client home screen — the brand
/// equivalent of the reference mockup's "iPhone 16 Pro / Shop Now" hero
/// banner, which auto-slides between a few bundled product photos (rather
/// than hotlinked images) with a swipeable `PageView` + dot indicator, so it
/// stays fully offline-safe like the rest of the catalog artwork.
class PromoHeroBanner extends StatefulWidget {
  const PromoHeroBanner({super.key});

  @override
  State<PromoHeroBanner> createState() => _PromoHeroBannerState();
}

class _PromoHeroBannerState extends State<PromoHeroBanner> {
  final _pageController = PageController();
  Timer? _autoSlideTimer;
  int _page = 0;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final next = (_page + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _autoSlideTimer?.cancel();
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _dismissed
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Container(
                height: 192,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: AppShadows.soft(brightness),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (index) =>
                            setState(() => _page = index),
                        itemBuilder: (context, index) =>
                            _SlideContent(slide: _slides[index]),
                      ),
                      Positioned(
                        bottom: AppSpacing.sm,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _slides.length; i++)
                              _SlideDot(active: i == _page),
                          ],
                        ),
                      ),
                      Positioned(
                        top: AppSpacing.sm,
                        right: AppSpacing.sm,
                        child: _CloseButton(onTap: _dismiss),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide});

  final _HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(slide.image, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.heroGradient[0].withValues(alpha: 0.92),
                AppColors.heroGradient[0].withValues(alpha: 0.55),
                AppColors.heroGradient[1].withValues(alpha: 0.15),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slide.headline,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brandPrimaryDeep,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                ),
                onPressed: () => context.push(AppRoutes.clientSearch),
                child: Text(
                  slide.cta,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SlideDot extends StatelessWidget {
  const _SlideDot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 1 : 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
    );
  }
}
