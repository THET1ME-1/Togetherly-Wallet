import 'dart:async';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/store.dart';
import 'services/local_push.dart';
import 'services/locale.dart';
import 'services/notices.dart';
import 'services/plus.dart';
import 'services/push.dart';
import 'services/analytics.dart';
import 'services/session.dart';
import 'services/live.dart';
import 'services/lock.dart';
import 'services/snapshots.dart';
import 'services/sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  final account = Session();
  // База и учётка читаются до первого кадра: иначе экран мигает пустотой и
  // только потом наполняется — ровно то, за что ругают веб-обёртки.
  // Язык читается до первого кадра вместе с базой: иначе экран мигает
  // русским и только потом переводится.
  final locale = AppLocale(
    system: WidgetsBinding.instance.platformDispatcher.locale,
  );
  final plus = PlusService(session: account);
  final lock = LockService();
  final snapshots = SnapshotService(session: account, store: store);
  await Future.wait([
    store.load(),
    account.load(),
    locale.load(),
    plus.load(),
    lock.load(),
    snapshots.load(),
  ]);
  // Подписка открывает платное в САМОЙ базе. Без этой связи флаг
  // `store.plusActive` оставался ложью навсегда, и написанный движок своих
  // правил разбора списаний не срабатывал ни разу (найдено 17.09.2026).
  // Слушатель, а не разовое чтение: талон приезжает сверкой с сервером уже
  // после запуска, и покупка обязана открывать правила в ту же секунду.
  void followPlus() => store.setPlusActive(plus.active);
  plus.addListener(followPlus);
  followPlus();
  // Аналитика заводится ПОСЛЕ чтения учётки: до неё неизвестно, кто открыл
  // приложение, и событие «запуск» ушло бы безымянным.
  unawaited(Analytics.instance.init(account, installId: store.installId));
  Analytics.instance.funnel(account.signedIn ? 'open' : 'open_guest');

  final sync = Sync(session: account, store: store);
  final notices = Notices(store);
  final push = Push();
  final local = LocalPush();
  // Колбэк ставится тут, а не в приложении: канал поднимается раньше первого
  // кадра, и событие, пришедшее в эту секунду, терять незачем.
  late final Live live;
  live = Live(
    session: account,
    sync: sync,
    onPartnerWrote: () {
      // Где пуши доходят, уведомление придёт от Google — второе было бы
      // дублем. Где не доходят, поднимаем сами.
      if (push.needsLocal) local.partnerWrote();
    },
  );
  runApp(MoneyApp(
    store: store,
    account: account,
    sync: sync,
    live: live,
    notices: notices,
    push: push,
    local: local,
    locale: locale,
    plus: plus,
    lock: lock,
    snapshots: snapshots,
  ));
}
