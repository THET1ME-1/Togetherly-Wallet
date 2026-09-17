import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:togetherly_money/logic/shots.dart';

/// Снимок чека уезжает в чат о деньгах, и уезжал он как есть — кадром с
/// камеры на несколько мегабайт. В теле запроса он идёт base64, то есть ещё
/// на треть больше; по мобильной сети одна отправка съедала больше времени,
/// чем весь разбор на сервере, и человек видел «Сервер не отвечает».

Uint8List photo(int w, int h) {
  final im = img.Image(width: w, height: h);
  // Шум, а не заливка: однотонный кадр жмётся в килобайты, и проверка
  // ужатия на нём ничего не покажет.
  var seed = 7;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      im.setPixelRgb(x, y, seed % 255, (seed >> 8) % 255, (seed >> 16) % 255);
    }
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  test('кадр с камеры ужимается в разы', () {
    final raw = photo(3000, 4000);
    final small = shrinkShot(raw);

    expect(small.length, lessThan(raw.length ~/ 4),
        reason: 'ради этого всё и делается: тело запроса должно похудеть');
    final back = img.decodeImage(small)!;
    expect(back.height, shotSide, reason: 'длинная сторона приведена к 1600');
    expect(back.width, lessThan(back.height));
  });

  test('горизонтальный кадр ужимается по своей длинной стороне', () {
    final back = img.decodeImage(shrinkShot(photo(4000, 2000)))!;
    expect(back.width, shotSide);
    expect(back.height, lessThan(back.width));
  });

  test('маленький снимок не трогаем', () {
    final raw = photo(300, 200);
    expect(shrinkShot(raw), same(raw),
        reason: 'портить то, что и так годится, незачем');
  });

  test('чужой формат возвращается как есть', () {
    final junk = Uint8List.fromList(List.filled(300 * 1024, 42));
    expect(shrinkShot(junk), same(junk),
        reason: 'не разобрали кадр — отправляем исходник, а не падаем');
  });

  test('уже плотный кадр не раздувается', () {
    // JPEG 1200×900 меньше нашего результата — оставляем исходный.
    final im = img.Image(width: 1200, height: 900);
    img.fill(im, color: img.ColorRgb8(240, 240, 240));
    final jpg = Uint8List.fromList(img.encodeJpg(im, quality: 40));
    final padded = Uint8List.fromList([...jpg, ...List.filled(250 * 1024, 0)]);
    final out = shrinkShot(padded);
    expect(out.length, lessThanOrEqualTo(padded.length));
  });
}
