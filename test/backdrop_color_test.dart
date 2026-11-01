import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netease_client/widgets/backdrop_color.dart';

void main() {
  double hueOf(Color c) => HSLColor.fromColor(c).hue;

  test('uses the dominant (first) color when it is vivid enough', () {
    const pink = Color(0xFFF7A8C8);
    final c = backdropColorFor(const [pink, Color(0xFFFFD98A)]);
    expect(hueOf(c), closeTo(hueOf(pink), 1));
    expect(HSLColor.fromColor(c).lightness, closeTo(0.32, 0.01));
  });

  test('falls back to the most vivid color when the first is greyscale', () {
    const red = Color(0xFFE53935);
    final c = backdropColorFor(const [Color(0xFF808080), Color(0xFFFFFFFF), red]);
    expect(hueOf(c), closeTo(hueOf(red), 1));
    expect(HSLColor.fromColor(c).saturation, lessThanOrEqualTo(0.6 + 1e-9));
  });
}
