/// Снимки, которые уезжают в чат о деньгах.
///
/// Телефон отдаёт кадр как есть: скриншот на 2 МБ, фотография чека на шесть.
/// В теле запроса он едет base64, то есть ещё на треть больше, и по мобильной
/// сети одна отправка съедает больше времени, чем весь разбор на сервере.
/// Зрячей модели столько не нужно: сумму и магазин она читает и с 1600 точек
/// по длинной стороне.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Длинная сторона снимка после ужатия.
const shotSide = 1600;

/// Качество JPEG. Восемьдесят два — там, где текст чека ещё читается, а вес
/// уже в разы меньше.
const shotQuality = 82;

/// Ужать снимок для отправки. Возвращает исходные байты, если кадр не
/// разобрался (экзотический формат) или и так маленький: портить то, что уже
/// годится, незачем.
Uint8List shrinkShot(Uint8List raw, {int side = shotSide, int quality = shotQuality}) {
  if (raw.length < 200 * 1024) return raw;

  final decoded = img.decodeImage(raw);
  if (decoded == null) return raw;

  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final fitted = longest <= side
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? side : null,
          height: decoded.height > decoded.width ? side : null,
          interpolation: img.Interpolation.average,
        );

  final out = img.encodeJpg(fitted, quality: quality);
  // Бывает, что исходник уже плотнее нашего JPEG — тогда оставляем его.
  return out.length < raw.length ? Uint8List.fromList(out) : raw;
}

/// Во сколько раз ужалось. Для строки в отчёте и для тестов.
double shrinkRatio(int before, int after) => after == 0 ? 1 : before / after;
