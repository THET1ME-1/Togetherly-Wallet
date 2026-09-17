import 'dart:ui' as ui;

/// Языки интерфейса — те же семь, что в Togetherly: одна экосистема, и человек,
/// переключивший там язык, ждёт того же списка здесь.
///
/// Русский переведён полностью, английский — следом за ним. Остальные пять
/// заведены заготовками: ключ без перевода откатывается на английский (см.
/// `tr` в `strings.dart`), поэтому выбрать немецкий можно уже сейчас и экран
/// не сломается — он просто будет английским, пока строки не доедут.
enum MoneyLanguage {
  ru('ru', 'Русский'),
  en('en', 'English'),
  de('de', 'Deutsch'),
  fr('fr', 'Français'),
  es('es', 'Español'),
  it('it', 'Italiano'),
  pt('pt', 'Português');

  const MoneyLanguage(this.code, this.label);

  /// Код языка — он же колонка в словаре.
  final String code;

  /// Название на самом языке: список выбора читают те, кто нашего языка не
  /// знает.
  final String label;

  static MoneyLanguage? byCode(String code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }

  /// Язык устройства → наш язык.
  ///
  /// Страна важна там, где язык системы английский, а живёт человек иначе:
  /// у Молдовы и Казахстана телефон нередко стоит на английском, а язык
  /// обиходный — русский.
  static MoneyLanguage detect(ui.Locale locale) {
    final code = locale.languageCode.toLowerCase();
    final byLang = byCode(code);
    // Свой язык сильнее страны — кроме английского: он стоит на телефонах у
    // тех, кто говорит иначе, и страна тогда единственная подсказка.
    if (byLang != null && byLang != MoneyLanguage.en) return byLang;

    const byCountry = <String, MoneyLanguage>{
      'RU': MoneyLanguage.ru,
      'BY': MoneyLanguage.ru,
      'KZ': MoneyLanguage.ru,
      'KG': MoneyLanguage.ru,
      'UA': MoneyLanguage.ru,
      'MD': MoneyLanguage.ru,
      'DE': MoneyLanguage.de,
      'AT': MoneyLanguage.de,
      'CH': MoneyLanguage.de,
      'FR': MoneyLanguage.fr,
      'BE': MoneyLanguage.fr,
      'LU': MoneyLanguage.fr,
      'ES': MoneyLanguage.es,
      'MX': MoneyLanguage.es,
      'AR': MoneyLanguage.es,
      'CO': MoneyLanguage.es,
      'CL': MoneyLanguage.es,
      'IT': MoneyLanguage.it,
      'PT': MoneyLanguage.pt,
      'BR': MoneyLanguage.pt,
    };
    return byCountry[locale.countryCode?.toUpperCase() ?? ''] ??
        byLang ??
        MoneyLanguage.en;
  }
}
