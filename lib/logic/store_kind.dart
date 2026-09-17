/// Откуда поставлено приложение. Задаётся сборкой:
/// `--dart-define=STORE=play|rustore|github|appstore`.
///
/// От этого зависит, чем человек платит. У Play свой биллинг и свои правила,
/// у RuStore нашего товара нет вовсе, а сборка с GitHub магазина не знает —
/// этим двум остаётся касса lava, и она же единственная работает в России,
/// где Google денег не принимает.
library;

const String kStore = String.fromEnvironment('STORE', defaultValue: 'github');

/// Платит ли магазин сам, своим биллингом.
bool get storeHasBilling => kStore == 'play' || kStore == 'appstore';

/// Платим ли мы через lava: сборки RuStore и GitHub.
bool get storePaysByLava => !storeHasBilling;
