import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import '../services/ads.dart';
import '../services/analytics.dart';

/// Баннер РСЯ строкой между блоками.
///
/// Пока баннер не загрузился, места он НЕ занимает: пустая серая полоса между
/// балансом и счетами читается как поломка экрана, а не как «реклама ещё
/// летит». Загрузился — появляется вместе со своим отступом.
///
/// Подписчику баннер не строится вовсе: `Ads.show` отвечает за это одним
/// местом, и проверять подписку на каждом экране не нужно.
class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    required this.ads,
    required this.spot,
    this.height = 100,
  });

  final Ads ads;

  /// Место на экране: от него зависит блок, а значит и строка в отчёте.
  final AdSpot spot;

  /// Потолок высоты. Врезной баннер сам выберет высоту не больше этой: на
  /// главной экран и так длинный, и половина его под рекламу не годится.
  final double height;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  double _width = 0;

  @override
  void initState() {
    super.initState();
    // Купил подписку — баннер обязан пропасть В ТУ ЖЕ СЕКУНДУ, а не при
    // следующем заходе на экран: первое, что человек проверяет после оплаты,
    // это исчезла ли реклама.
    widget.ads.addListener(_onAds);
  }

  void _onAds() {
    if (!mounted) return;
    if (!widget.ads.show) {
      _ad?.destroy();
      _ad = null;
      _width = 0;
    }
    setState(() => _loaded = _loaded && widget.ads.show);
  }

  @override
  void dispose() {
    widget.ads.removeListener(_onAds);
    _ad?.destroy();
    super.dispose();
  }

  Future<void> _load(double width) async {
    if (!widget.ads.show) return;
    // Ширина известна только после разметки, а размер баннера задаётся до
    // загрузки: ждём первого замера и грузим один раз на эту ширину.
    if (_ad != null && (_width - width).abs() < 1) return;
    _ad?.destroy();
    _width = width;
    _loaded = false;

    final ad = BannerAd(
      adSize: BannerAdSize.inline(
        width: width.round(),
        maxHeight: widget.height.round(),
      ),
    );
    _ad = ad;
    ad.loadStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _loaded = state is BannerAdLoadStateLoaded);
      if (state is BannerAdLoadStateLoaded) {
        Analytics.instance.ad(widget.spot.name);
      }
    });
    try {
      await ad.load(AdRequest(adUnitId: widget.ads.unitFor(widget.spot)));
    } catch (_) {
      if (mounted) setState(() => _loaded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ads.show) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth.isFinite ? box.maxWidth : 0.0;
        if (width > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _load(width));
        }
        final ad = _ad;
        if (ad == null || !_loaded) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: width,
              height: widget.height,
              child: AdWidget(bannerAd: ad),
            ),
          ),
        );
      },
    );
  }
}
