import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

/// Замок на вход: код и отпечаток.
///
/// Код хранится СОЛЁНЫМ ХЕШЕМ, а не числом. База лежит файлом на телефоне, и
/// «1234» в соседнем файле открыло бы её любому, кто до этого файла добрался.
/// Соль своя у каждого устройства: без неё четырёхзначный код подбирается по
/// готовой таблице за секунды.
///
/// Замок не шифрует базу и не притворяется, что шифрует: он закрывает деньги
/// от того, кто взял телефон в руки. Обещать больше — врать.
class LockService extends ChangeNotifier {
  LockService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;
  File? _file;

  String _salt = '';
  String _hash = '';
  bool _biometrics = false;

  /// Закрыт ли замок прямо сейчас. При запуске — да, если код заведён.
  bool _locked = false;

  /// Когда приложение ушло в фон. Из этого считается, пора ли запирать.
  DateTime? _left;

  /// Сколько замок ждёт, прежде чем запереться снова.
  ///
  /// Минута, а не мгновенно: человек выходит в сообщения посмотреть сумму
  /// перевода и возвращается. Замок, который спрашивает код на каждое
  /// переключение, выключают в тот же день.
  static const graceSeconds = 60;

  bool get enabled => _hash.isNotEmpty;
  bool get locked => _locked;
  bool get biometrics => _biometrics;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/lock.json');
      if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString());
        if (raw is Map) {
          _salt = '${raw['salt'] ?? ''}';
          _hash = '${raw['hash'] ?? ''}';
          _biometrics = raw['biometrics'] == true;
        }
      }
    } catch (_) {
      // Битый файл не запирает приложение навсегда: замка просто нет.
      _salt = '';
      _hash = '';
    }
    _locked = enabled;
    notifyListeners();
  }

  /// Завести или сменить код.
  Future<void> setPin(String pin) async {
    _salt = _newSalt();
    _hash = _digest(pin, _salt);
    _locked = false;
    await _save();
  }

  /// Снять замок совсем.
  Future<void> disable() async {
    _salt = '';
    _hash = '';
    _biometrics = false;
    _locked = false;
    await _save();
  }

  Future<void> setBiometrics(bool value) async {
    _biometrics = value;
    await _save();
  }

  /// Тот ли код. Открывает замок при совпадении.
  bool unlock(String pin) {
    if (!enabled) return true;
    final ok = _digest(pin, _salt) == _hash;
    if (ok) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }

  /// Спросить отпечаток. Отказ или отсутствие датчика — не беда: код никуда
  /// не делся, и человек вводит его руками.
  Future<bool> unlockByBiometrics() async {
    if (!enabled || !_biometrics) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Wallet',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) {
        _locked = false;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Есть ли на устройстве отпечаток или лицо.
  Future<bool> canBiometrics() async {
    try {
      return await _auth.canCheckBiometrics ||
          await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Приложение ушло в фон.
  ///
  /// Время ухода запоминается ОДИН раз, до возвращения. Android шлёт
  /// `inactive` и перед сворачиванием, и перед возвратом; без этой оговорки
  /// вторая отметка затирала первую, away выходил нулевым, и замок не
  /// запирался вовсе — поймано на живом эмуляторе 17.09.2026.
  void leave({DateTime? at}) => _left ??= at ?? DateTime.now();

  /// Приложение вернулось. Запирает, если в фоне пробыли дольше грейса.
  void comeBack({DateTime? at}) {
    final left = _left;
    _left = null;
    if (!enabled || _locked || left == null) return;
    final away = (at ?? DateTime.now()).difference(left).inSeconds;
    if (away >= graceSeconds) {
      _locked = true;
      notifyListeners();
    }
  }

  /// Запереть прямо сейчас — по просьбе человека из настроек.
  void lockNow() {
    if (!enabled || _locked) return;
    _locked = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      if (!enabled) {
        if (await (_file?.exists() ?? Future.value(false))) {
          await _file!.delete();
        }
      } else {
        await _file?.writeAsString(jsonEncode({
          'salt': _salt,
          'hash': _hash,
          'biometrics': _biometrics,
        }));
      }
    } catch (_) {
      // Не записалось — замок доживёт до перезапуска. Молча терять код хуже,
      // чем оставить его в памяти.
    }
    notifyListeners();
  }

  static String _newSalt() {
    final rnd = Random.secure();
    return base64Url.encode([for (var i = 0; i < 16; i++) rnd.nextInt(256)]);
  }

  static String _digest(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt|$pin')).toString();

  /// Подставить состояние в тестах.
  @visibleForTesting
  void setForTest({String pin = '', bool locked = false}) {
    if (pin.isEmpty) {
      _salt = '';
      _hash = '';
    } else {
      _salt = 'test-salt';
      _hash = _digest(pin, _salt);
    }
    _locked = locked;
    notifyListeners();
  }
}
