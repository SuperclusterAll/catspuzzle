// 냥냥 합체 고양이 SVG 생성기.
//
//   dart run tool/gen_cat_svgs.dart
//
// 얼굴만 그린다 (몸통/발/꼬리 없음). assets/cats/ 에 두 층을 만든다.
//   body_t{단계}_{털색}.svg : 머리, 귀, 털 실루엣, 무늬, 입가, 소품
//   face_t{단계}_{표정}.svg : 눈, 볼, 코, 입, 수염 (품종마다 눈 색·비율이 다르다)
// 좌표는 반지름 1인 머리 기준, viewBox -1.6..1.6.
// 일러스트레이터가 SVG를 직접 고쳐도 된다. 다시 생성하면 덮어쓰니 주의.
import 'dart:io';
import 'dart:math';

class Coat {
  const Coat(this.fur,
      {this.mark, this.mark2, this.muzzle, this.point, this.mane, this.marks = const {}});

  final String fur;

  /// 줄무늬/점무늬 색. 삼색은 [mark]가 주황, [mark2]가 검정.
  final String? mark;
  final String? mark2;

  /// 입가·턱 색 (없으면 털색을 밝게).
  final String? muzzle;

  /// 샴 포인트(귀·마스크) 색.
  final String? point;

  /// 사자 갈기 색.
  final String? mane;

  /// tabbyM, cheekStripes, mackerel, rosettes, mask, tuxedo, calico, sheen
  final Set<String> marks;
}

class Breed {
  const Breed({
    required this.ears,
    required this.fluff,
    required this.eyes,
    this.eyes2,
    this.nose = 'f28b9b',
    this.flat = false,
    this.accessory,
    required this.coats,
  });

  /// normal, big, fold, tiny, lynx, round
  final String ears;

  /// 0 없음, 1 뺨털, 2 풍성한 목털, 3 얼굴 둘레 전체 (페르시안)
  final int fluff;

  /// 눈동자 (위, 아래) 색. [eyes2]가 있으면 오른쪽 눈 (오드아이).
  final (String, String) eyes;
  final (String, String)? eyes2;
  final String nose;

  /// 납작한 얼굴 (이목구비가 가운데로 모인다).
  final bool flat;
  final String? accessory;

  /// CatCoat 순서 (base, alt, rare).
  final List<Coat> coats;
}

const _tabby = {'tabbyM', 'cheekStripes'};

/// lib/games/cat_merge/cat_tiers.dart 의 catTiers 순서와 같다.
const breeds = <Breed>[
  // 0 터키시 앙고라: 새하얀 털, 오드아이, 리본
  Breed(
    ears: 'big',
    fluff: 1,
    eyes: ('4f93e0', 'b9e0ff'),
    eyes2: ('d99a2b', 'ffd98a'),
    accessory: 'ribbon',
    coats: [
      Coat('ffffff', muzzle: 'ffffff'),
      Coat('f5e3c3', muzzle: 'fff6e6'),
      Coat('dde2ea', muzzle: 'f4f6f9', marks: {'sheen'}),
    ],
  ),
  // 1 코리안숏헤어: 치즈 태비
  Breed(
    ears: 'normal',
    fluff: 1,
    eyes: ('c77d1e', 'f6cf6a'),
    coats: [
      Coat('e8943a', mark: 'c0661c', muzzle: 'fff3e3', marks: _tabby),
      Coat('f3c58a', mark: 'd99a55', muzzle: 'fff8ee', marks: _tabby),
      Coat('fbf6ee', mark: 'e8943a', mark2: '3b3633', muzzle: 'ffffff', marks: {'calico'}),
    ],
  ),
  // 2 러시안블루: 은빛 윤기, 에메랄드 눈
  Breed(
    ears: 'big',
    fluff: 0,
    eyes: ('2f8f5b', '9ae6a8'),
    nose: '7f86a0',
    coats: [
      Coat('7f8fa6', marks: {'sheen'}),
      Coat('a3b0c2', marks: {'sheen'}),
      Coat('b7a3b1', marks: {'sheen'}),
    ],
  ),
  // 3 샴: 얼굴 마스크, 사파이어 눈
  Breed(
    ears: 'big',
    fluff: 0,
    eyes: ('2e6fd1', '9fd0ff'),
    nose: '6b4a3a',
    coats: [
      Coat('f3e6d3', point: '4e3527', marks: {'mask'}),
      Coat('eef0f2', point: '6d7a8c', marks: {'mask'}),
      Coat('fbeee0', point: 'd9803a', marks: {'mask'}),
    ],
  ),
  // 4 코숏 고등어
  Breed(
    ears: 'normal',
    fluff: 1,
    eyes: ('7a9a2e', 'dfe06a'),
    nose: 'd98a86',
    coats: [
      Coat('9a948a', mark: '3e3a36', muzzle: 'f7f3ec', marks: {..._tabby, 'mackerel'}),
      Coat('c7ccd2', mark: '4a4f57', muzzle: 'f7f8fa', marks: {..._tabby, 'mackerel'}),
      Coat('a3876a', mark: '4a3526', muzzle: 'f5ece0', marks: {..._tabby, 'mackerel'}),
    ],
  ),
  // 5 코숏 턱시도: 흰 코 줄기, 노란 눈
  Breed(
    ears: 'normal',
    fluff: 1,
    eyes: ('d9a520', 'ffe46e'),
    coats: [
      Coat('2f2a28', muzzle: 'faf7f0', marks: {'tuxedo'}),
      Coat('4a4a52', muzzle: 'faf7f0', marks: {'tuxedo'}),
      Coat('3d4658', muzzle: 'faf7f0', marks: {'tuxedo'}),
    ],
  ),
  // 6 스코티시폴드: 접힌 귀, 동그란 구리빛 눈, 꽃
  Breed(
    ears: 'fold',
    fluff: 1,
    eyes: ('b8651e', 'f5b060'),
    accessory: 'flower',
    coats: [
      Coat('fbf6ee', mark: 'e8943a', mark2: '3b3633', muzzle: 'ffffff', marks: {'calico'}),
      Coat('f2d3a2', muzzle: 'fff4e2'),
      Coat('8e9bb0', muzzle: 'c9d1dd', marks: {'sheen'}),
    ],
  ),
  // 7 뱅갈: 표범 무늬
  Breed(
    ears: 'normal',
    fluff: 0,
    eyes: ('4f9a3a', 'c2e882'),
    nose: 'c46a4a',
    coats: [
      Coat('e2a24a', mark: '5a3a1e', muzzle: 'fbe9cf', marks: {'rosettes', 'tabbyM'}),
      Coat('f1ece2', mark: '9c8a74', muzzle: 'ffffff', marks: {'rosettes', 'tabbyM'}),
      Coat('cfd3d8', mark: '2f2f33', muzzle: 'f4f5f7', marks: {'rosettes', 'tabbyM'}),
    ],
  ),
  // 8 페르시안: 얼굴 둘레 솜털, 납작한 얼굴, 작은 귀
  Breed(
    ears: 'tiny',
    fluff: 3,
    eyes: ('c0601a', 'f7a650'),
    flat: true,
    coats: [
      Coat('f6e3c4', muzzle: 'fff4e4'),
      Coat('ffffff', muzzle: 'ffffff'),
      Coat('eef0f3', muzzle: 'ffffff', marks: {'sheen'}),
    ],
  ),
  // 9 메인쿤: 스라소니 귀 끝 털, 풍성한 목털
  Breed(
    ears: 'lynx',
    fluff: 2,
    eyes: ('9a8a2a', 'ecd96e'),
    nose: 'c9786a',
    coats: [
      Coat('a0673f', mark: '3e2a1c', muzzle: 'f3e6d6', marks: {..._tabby, 'mackerel'}),
      Coat('d9772b', mark: '9c4314', muzzle: 'fbe7d2', marks: {..._tabby, 'mackerel'}),
      Coat('bfc4ca', mark: '3a3d42', muzzle: 'f4f5f7', marks: {..._tabby, 'mackerel'}),
    ],
  ),
  // 10 사자: 갈기, 왕관
  Breed(
    ears: 'round',
    fluff: 0,
    eyes: ('b07a1a', 'f5c64e'),
    nose: '8a553a',
    accessory: 'crown',
    coats: [
      Coat('f4c542', muzzle: 'fff1c9', mane: 'd9932f'),
      Coat('fbf3e0', muzzle: 'ffffff', mane: 'e6d2ad'),
      Coat('f9d7dc', muzzle: 'fff2f4', mane: 'f29bb0'),
    ],
  ),
];

/// 기본 털색. cat_tiers.dart 의 fur 와 같아야 한다 (테스트로 확인).
final furHex = [for (final b in breeds) b.coats.first.fur];

/// CatCoat.name 순서와 같다.
const coats = ['base', 'alt', 'rare'];

/// CatFace.name 순서와 같다.
const faces = [
  'calm',
  'sleepy',
  'sparkle',
  'smile',
  'happy',
  'wink',
  'content',
  'bleh',
  'proud',
  'surprised',
  'love',
  'blink',
];

const lionTier = 10;
const _ink = '3a2a24';
const _eyeLine = '24181a';

bool _darkHex(String h) => _lum(h) < 0.12;
bool isDark(int tier) => _darkHex(furHex[tier]);

void main() {
  final dir = Directory('assets/cats')..createSync(recursive: true);
  for (final f in dir.listSync().whereType<File>()) {
    if (f.path.endsWith('.svg')) f.deleteSync();
  }
  for (var t = 0; t < breeds.length; t++) {
    final b = breeds[t];
    assert(b.coats.length == coats.length);
    for (var c = 0; c < coats.length; c++) {
      // 같은 품종 안에서는 밝기 계열이 같아야 얼굴 층을 같이 쓸 수 있다.
      if (_darkHex(b.coats[c].fur) != isDark(t)) {
        throw StateError('tier $t coat ${coats[c]}: 밝기 계열이 기본 털색과 다름');
      }
      File('${dir.path}/body_t${t}_${coats[c]}.svg').writeAsStringSync(head(t, c));
    }
    for (final f in faces) {
      File('${dir.path}/face_t${t}_$f.svg').writeAsStringSync(face(t, f));
    }
  }
  stdout.writeln('wrote ${breeds.length * coats.length} heads, '
      '${breeds.length * faces.length} faces to ${dir.path}');
}

// ---------------------------------------------------------------- 공통

List<int> _rgb(String h) =>
    [for (var i = 0; i < 3; i++) int.parse(h.substring(i * 2, i * 2 + 2), radix: 16)];

String _hex(List<num> c) =>
    c.map((v) => v.round().clamp(0, 255).toRadixString(16).padLeft(2, '0')).join();

String mix(String a, String b, double t) {
  final x = _rgb(a), y = _rgb(b);
  return _hex([for (var i = 0; i < 3; i++) x[i] + (y[i] - x[i]) * t]);
}

double _lum(String h) {
  double ch(int v) {
    final s = v / 255;
    return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final c = _rgb(h);
  return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2]);
}

String n(num v) {
  final s = v.toStringAsFixed(3);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _svg(String defs, String content) => '''
<svg xmlns="http://www.w3.org/2000/svg" width="3.2" height="3.2" viewBox="-1.6 -1.6 3.2 3.2">
<defs>$defs</defs>
$content
</svg>
''';

/// 이목구비 배치. 페르시안은 납작하게 가운데로 모인다.
class _Geo {
  const _Geo(this.eyeX, this.eyeY, this.eyeW, this.eyeH, this.noseY);
  final double eyeX, eyeY, eyeW, eyeH, noseY;
  double get mouthY => noseY + 0.075;
}

_Geo _geo(Breed b) => b.flat
    ? const _Geo(0.37, 0.07, 0.37, 0.4, 0.25)
    : const _Geo(0.4, 0.02, 0.34, 0.4, 0.3);

// ---------------------------------------------------------------- 머리

/// 뾰족 귀. [lift]만큼 귀 끝이 더 높다.
String _earPath(double s, {double lift = 0}) => 'M ${n(s * -0.96)} -0.2 '
    'Q ${n(s * -0.99)} ${n(-0.84 - lift)} ${n(s * -0.82)} ${n(-1.1 - lift)} '
    'Q ${n(s * -0.72)} ${n(-1.22 - lift)} ${n(s * -0.6)} ${n(-1.12 - lift)} '
    'Q ${n(s * -0.34)} ${n(-0.96 - lift * 0.5)} ${n(s * -0.08)} -0.86 Z';

String _innerEarPath(double s, {double lift = 0}) => 'M ${n(s * -0.8)} -0.42 '
    'Q ${n(s * -0.85)} ${n(-0.86 - lift)} ${n(s * -0.75)} ${n(-1.01 - lift)} '
    'Q ${n(s * -0.68)} ${n(-1.08 - lift)} ${n(s * -0.6)} ${n(-1.01 - lift)} '
    'Q ${n(s * -0.45)} ${n(-0.91 - lift * 0.5)} ${n(s * -0.28)} -0.8 Z';

String _tinyEar(double s) => 'M ${n(s * -0.84)} -0.46 '
    'Q ${n(s * -0.86)} -1.02 ${n(s * -0.68)} -1.12 '
    'Q ${n(s * -0.52)} -0.94 ${n(s * -0.36)} -0.82 Z';

/// 접힌 귀: 앞으로 폭 덮인 작은 귀.
String _foldEar(double s) => 'M ${n(s * -0.88)} -0.52 '
    'Q ${n(s * -0.94)} -0.92 ${n(s * -0.62)} -0.98 '
    'Q ${n(s * -0.36)} -1 ${n(s * -0.28)} -0.8 '
    'Q ${n(s * -0.56)} -0.66 ${n(s * -0.88)} -0.52 Z';

String _cheekFluff(double s) => 'M ${n(s * -0.94)} 0.02 '
    'Q ${n(s * -1.13)} 0.1 ${n(s * -1.03)} 0.2 '
    'Q ${n(s * -1.16)} 0.3 ${n(s * -1.01)} 0.38 '
    'Q ${n(s * -1.08)} 0.5 ${n(s * -0.88)} 0.52 Z';

String _ruff(double s) => 'M ${n(s * -0.9)} -0.12 '
    'Q ${n(s * -1.22)} -0.04 ${n(s * -1.1)} 0.12 '
    'Q ${n(s * -1.3)} 0.24 ${n(s * -1.12)} 0.38 '
    'Q ${n(s * -1.26)} 0.54 ${n(s * -1.02)} 0.6 '
    'Q ${n(s * -1.08)} 0.8 ${n(s * -0.82)} 0.8 '
    'Q ${n(s * -0.7)} 0.96 ${n(s * -0.5)} 0.88 Z';

List<(double, double)> _ring(int count, double radius) => [
      for (var i = 0; i < count; i++)
        (cos(i * 2 * pi / count) * radius, sin(i * 2 * pi / count) * radius),
    ];

String head(int t, int ci) {
  final b = breeds[t];
  final c = b.coats[ci];
  final g = _geo(b);
  final fur = c.fur;
  final dark = _darkHex(fur);
  final line = dark ? '1a1614' : mix(fur, _ink, 0.5);
  final light = mix(fur, 'ffffff', dark ? 0.15 : 0.45);
  final shadow = mix(fur, _ink, 0.55);
  final markC = c.mark ?? mix(fur, _ink, 0.3);
  final calico = c.marks.contains('calico');
  final earL = calico ? c.mark! : (c.point ?? fur);
  final earR = calico ? c.mark2! : (c.point ?? fur);
  final lift = switch (b.ears) { 'big' => 0.1, 'lynx' => 0.16, _ => 0.0 };

  final defs = StringBuffer()
    ..write('<clipPath id="head"><circle r="1"/></clipPath>')
    ..write('<radialGradient id="shade" gradientUnits="userSpaceOnUse" cx="-0.3" cy="-0.46" r="1.7">'
        '<stop offset="0" stop-color="#ffffff" stop-opacity="0.4"/>'
        '<stop offset="0.42" stop-color="#ffffff" stop-opacity="0"/>'
        '<stop offset="0.76" stop-color="#$shadow" stop-opacity="0"/>'
        '<stop offset="1" stop-color="#$shadow" stop-opacity="0.4"/></radialGradient>')
    ..write('<linearGradient id="earIn" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#ffc9cf"/><stop offset="1" stop-color="#f08d9b"/></linearGradient>')
    ..write('<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#ffe38a"/><stop offset="1" stop-color="#e0a526"/></linearGradient>')
    ..write('<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1">'
        '<stop offset="0" stop-color="#ffffff" stop-opacity="0.35"/>'
        '<stop offset="0.5" stop-color="#ffffff" stop-opacity="0"/></linearGradient>');
  if (c.point != null) {
    defs.write('<radialGradient id="mask" gradientUnits="userSpaceOnUse" cx="0" cy="${n(g.noseY)}" r="0.78">'
        '<stop offset="0" stop-color="#${c.point}" stop-opacity="0.95"/>'
        '<stop offset="0.5" stop-color="#${c.point}" stop-opacity="0.7"/>'
        '<stop offset="1" stop-color="#${c.point}" stop-opacity="0"/></radialGradient>');
  }
  if (c.mane != null) {
    defs.write('<radialGradient id="mane" cx="0.5" cy="0.45" r="0.6">'
        '<stop offset="0.6" stop-color="#${c.mane}"/>'
        '<stop offset="1" stop-color="#${mix(c.mane!, _ink, 0.3)}"/></radialGradient>');
  }

  final o = StringBuffer();

  // 사자 갈기 (맨 뒤)
  if (c.mane != null) {
    final dots = _ring(16, 1.14);
    final edge = mix(c.mane!, _ink, 0.5);
    o.write('<g fill="#$edge"><circle r="1.2"/>'
        '${dots.map((d) => '<circle cx="${n(d.$1)}" cy="${n(d.$2)}" r="0.3"/>').join()}</g>');
    o.write('<g fill="url(#mane)"><circle r="1.14"/>'
        '${dots.map((d) => '<circle cx="${n(d.$1)}" cy="${n(d.$2)}" r="0.24"/>').join()}</g>');
    // 갈기 털결
    for (final d in _ring(16, 1.14)) {
      final a = atan2(d.$2, d.$1);
      o.write('<path d="M ${n(cos(a) * 1.02)} ${n(sin(a) * 1.02)} L ${n(cos(a + 0.08) * 1.26)} ${n(sin(a + 0.08) * 1.26)}" '
          'stroke="#$edge" stroke-width="0.03" stroke-linecap="round" opacity="0.5"/>');
    }
  }

  // 윤곽선 → 채움. 외곽 도형을 굵은 선으로 먼저 깔고 그 위에 채움을 덮어서
  // 겹치는 곳의 선을 가린다 (하나로 이어진 스티커 윤곽).
  final shapes = <(String, String)>[
    // 페르시안 솜털은 귀보다 뒤에 깐다 (작은 귀가 털 위로 빼꼼 보이게).
    if (b.fluff == 3)
      for (final d in _ring(22, 0.95))
        ('<circle cx="${n(d.$1)}" cy="${n(d.$2)}" r="0.14"/>', fur),
    ...switch (b.ears) {
      'round' => [
          ('<circle cx="-0.6" cy="-0.78" r="0.25"/>', earL),
          ('<circle cx="0.6" cy="-0.78" r="0.25"/>', earR),
        ],
      'tiny' => [('<path d="${_tinyEar(1)}"/>', earL), ('<path d="${_tinyEar(-1)}"/>', earR)],
      'fold' => [('<path d="${_foldEar(1)}"/>', earL), ('<path d="${_foldEar(-1)}"/>', earR)],
      _ => [
          ('<path d="${_earPath(1, lift: lift)}"/>', earL),
          ('<path d="${_earPath(-1, lift: lift)}"/>', earR),
        ],
    },
    if (b.fluff == 1) ...[
      ('<path d="${_cheekFluff(1)}"/>', calico ? c.mark! : fur),
      ('<path d="${_cheekFluff(-1)}"/>', calico ? fur : fur),
    ],
    if (b.fluff == 2) ...[
      ('<path d="${_ruff(1)}"/>', fur),
      ('<path d="${_ruff(-1)}"/>', fur),
    ],
    ('<circle r="1"/>', fur),
  ];
  o.write('<g fill="#$line" stroke="#$line" stroke-width="0.12" stroke-linejoin="round">'
      '${shapes.map((s) => s.$1).join()}</g>');
  for (final (shape, color) in shapes) {
    // 메인쿤 목털은 밝게. 얼굴 원을 덮기 전에 칠해 목털에만 남긴다.
    if (b.fluff == 2 && shape.startsWith('<circle r=')) {
      for (final s in [1.0, -1.0]) {
        o.write('<path d="${_ruff(s)}" fill="#${c.muzzle ?? light}" opacity="0.55"/>');
      }
    }
    o.write(shape.replaceFirst('/>', ' fill="#$color"/>'));
  }

  o.write(_innerEars(b, s: 1, lift: lift, ear: earL, line: line, light: light, point: c.point != null));
  o.write(_innerEars(b, s: -1, lift: lift, ear: earR, line: line, light: light, point: c.point != null));

  // 머리 안쪽: 무늬, 입가, 털결, 입체감
  o.write('<g clip-path="url(#head)">');
  if (calico) {
    o.write('<path d="M -1 -1 L 0.02 -1 Q 0.06 -0.56 -0.34 -0.4 Q -0.72 -0.26 -1 -0.08 Z" fill="#${c.mark}"/>'
        '<path d="M 1 -1 L 0.3 -1 Q 0.2 -0.66 0.54 -0.5 Q 0.84 -0.38 1 -0.36 Z" fill="#${c.mark2}"/>'
        '<ellipse cx="0.8" cy="0.5" rx="0.2" ry="0.16" fill="#${c.mark}"/>');
  }
  if (c.marks.contains('tuxedo')) {
    // 이마로 올라가는 흰 줄기 + 입가 전체
    o.write('<path d="M -0.7 1.02 Q -0.62 0.34 -0.14 0.08 Q -0.06 -0.32 0 -0.62 '
        'Q 0.06 -0.32 0.14 0.08 Q 0.62 0.34 0.7 1.02 Z" fill="#${c.muzzle}"/>');
  }
  if (c.marks.contains('mask')) {
    o.write('<ellipse cx="0" cy="${n(g.noseY - 0.04)}" rx="0.78" ry="0.66" fill="url(#mask)"/>');
  }
  if (c.marks.contains('tabbyM')) o.write(_tabbyM(markC));
  if (c.marks.contains('cheekStripes')) o.write(_cheekStripes(markC));
  if (c.marks.contains('mackerel')) o.write(_mackerel(markC));
  if (c.marks.contains('rosettes')) o.write(_rosettes(fur, markC));
  if (c.marks.contains('sheen')) {
    o.write('<rect x="-1" y="-1" width="2" height="1.2" fill="url(#sheen)"/>');
    for (final (x, y) in [(-0.55, -0.62), (-0.3, -0.78), (0.35, -0.74), (0.6, -0.5), (-0.7, -0.3), (0.72, -0.2)]) {
      o.write('<path d="M ${n(x)} ${n(y)} q 0.03 -0.05 0.07 -0.06" stroke="#ffffff" '
          'stroke-width="0.022" stroke-linecap="round" opacity="0.5" fill="none"/>');
    }
  }

  // 볼록한 입가 두 덩이 + 턱
  final puffColor = c.marks.contains('mask')
      ? mix(c.point!, fur, 0.25)
      : (c.muzzle ?? light);
  final puffOpacity = c.marks.contains('mask') ? 0.55 : (c.muzzle != null ? 1.0 : 0.75);
  final py = g.noseY + 0.14;
  o.write('<g fill="#$puffColor" opacity="${n(puffOpacity)}">'
      '<ellipse cx="-0.14" cy="${n(py)}" rx="0.19" ry="0.15"/>'
      '<ellipse cx="0.14" cy="${n(py)}" rx="0.19" ry="0.15"/>'
      '<ellipse cx="0" cy="${n(py + 0.16)}" rx="0.15" ry="0.1"/></g>');

  // 털결 (밝은 결 + 아래쪽 어두운 결)
  final hair = 'fill="none" stroke-width="0.024" stroke-linecap="round"';
  for (final s in [-1.0, 1.0]) {
    for (final (x, y, dx, dy) in [(0.8, -0.1, 0.1, 0.05), (0.86, 0.08, 0.1, 0.07), (0.82, 0.26, 0.09, 0.08)]) {
      o.write('<path d="M ${n(s * x)} ${n(y)} q ${n(s * dx * 0.6)} ${n(dy * 0.2)} ${n(s * dx)} ${n(dy)}" '
          'stroke="#${mix(fur, 'ffffff', 0.6)}" $hair opacity="0.55"/>');
    }
    o.write('<path d="M ${n(s * 0.5)} 0.82 q ${n(s * 0.06)} 0.04 ${n(s * 0.1)} 0.02" '
        'stroke="#$shadow" $hair opacity="0.3"/>');
  }
  for (final (x, h) in [(-0.1, 0.1), (0.04, 0.13), (0.16, 0.09)]) {
    o.write('<path d="M ${n(x)} -0.9 q 0.02 ${n(-h * 0.6)} 0.05 ${n(-h)}" '
        'stroke="#${mix(fur, 'ffffff', 0.55)}" $hair opacity="0.5"/>');
  }

  o.write('<rect x="-1" y="-1" width="2" height="2" fill="url(#shade)"/>');
  o.write('<ellipse cx="-0.46" cy="-0.56" rx="0.2" ry="0.09" fill="#ffffff" '
      'opacity="0.55" transform="rotate(-32 -0.46 -0.56)"/>');
  o.write('</g>');

  // 수염 자리 점
  for (final s in [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      o.write('<circle cx="${n(s * (0.1 + i * 0.07))}" cy="${n(py + 0.01 + (i - 1).abs() * -0.03 + 0.02)}" '
          'r="0.014" fill="#$line" opacity="0.45"/>');
    }
  }

  o.write(switch (b.accessory) {
    'ribbon' => _ribbon(line),
    'flower' => _flower(line),
    'crown' => _crown(),
    _ => '',
  });
  return _svg(defs.toString(), o.toString());
}

String _innerEars(Breed b,
    {required double s,
    required double lift,
    required String ear,
    required String line,
    required String light,
    required bool point}) {
  final o = StringBuffer();
  switch (b.ears) {
    case 'round':
      o.write('<circle cx="${n(s * -0.6)}" cy="-0.78" r="0.12" fill="url(#earIn)"/>');
    case 'tiny':
      o.write('<path d="M ${n(s * -0.76)} -0.52 Q ${n(s * -0.78)} -0.94 ${n(s * -0.67)} -1.02 '
          'Q ${n(s * -0.56)} -0.86 ${n(s * -0.46)} -0.76 Z" fill="url(#earIn)"/>');
    case 'fold':
      // 접힌 자국
      o.write('<path d="M ${n(s * -0.84)} -0.6 Q ${n(s * -0.6)} -0.72 ${n(s * -0.34)} -0.82" '
          'fill="none" stroke="#$line" stroke-width="0.03" stroke-linecap="round" opacity="0.55"/>'
          '<path d="M ${n(s * -0.78)} -0.66 Q ${n(s * -0.62)} -0.86 ${n(s * -0.42)} -0.88" '
          'fill="none" stroke="#ffffff" stroke-width="0.03" stroke-linecap="round" opacity="0.4"/>');
    default:
      o.write('<path d="${_innerEarPath(s, lift: lift)}" fill="url(#earIn)"'
          '${point ? ' opacity="0.45"' : ''}/>');
      // 귀 속 털
      final hairColor = _darkHex(ear) || point ? 'e8e0d8' : mix(light, 'ffffff', 0.4);
      o.write('<path d="M ${n(s * -0.66)} -0.64 q ${n(s * -0.06)} -0.14 ${n(s * -0.02)} ${n(-0.26 - lift * 0.5)} '
          'M ${n(s * -0.54)} -0.68 q ${n(s * 0.0)} -0.14 ${n(s * 0.06)} ${n(-0.22 - lift * 0.4)} '
          'M ${n(s * -0.74)} -0.54 q ${n(s * -0.06)} -0.1 ${n(s * -0.06)} -0.2" '
          'fill="none" stroke="#$hairColor" stroke-width="0.03" stroke-linecap="round" opacity="0.9"/>');
      if (b.ears == 'lynx') {
        // 스라소니 귀 끝 털
        final tipX = s * -0.72, tipY = -1.22 - lift;
        o.write('<path d="M ${n(tipX)} ${n(tipY + 0.04)} q ${n(s * 0.02)} -0.14 ${n(s * 0.08)} -0.22 '
            'M ${n(tipX + s * 0.04)} ${n(tipY + 0.04)} q ${n(s * 0.06)} -0.1 ${n(s * 0.14)} -0.14" '
            'fill="none" stroke="#3a2a24" stroke-width="0.035" stroke-linecap="round"/>');
      }
  }
  return o.toString();
}

String _tabbyM(String c) {
  final st = 'fill="none" stroke="#$c" stroke-linecap="round" stroke-linejoin="round"';
  return '<path d="M -0.3 -0.5 L -0.2 -0.7 L 0 -0.55 L 0.2 -0.7 L 0.3 -0.5" $st stroke-width="0.06" opacity="0.85"/>'
      '<path d="M 0 -0.95 V -0.66 M -0.15 -0.96 Q -0.15 -0.84 -0.12 -0.74 M 0.15 -0.96 Q 0.15 -0.84 0.12 -0.74" '
      '$st stroke-width="0.055" opacity="0.85"/>';
}

String _cheekStripes(String c) {
  final b = StringBuffer('<g fill="#$c" opacity="0.85">');
  for (final s in [-1.0, 1.0]) {
    for (final (y, len) in [(-0.14, 0.3), (0.06, 0.34), (0.24, 0.24)]) {
      b.write('<path d="M ${n(s * 1.02)} ${n(y - 0.045)} Q ${n(s * (1.02 - len))} ${n(y)} '
          '${n(s * 1.02)} ${n(y + 0.045)} Z"/>');
    }
  }
  b.write('</g>');
  return b.toString();
}

String _mackerel(String c) {
  final st = 'fill="none" stroke="#$c" stroke-width="0.055" stroke-linecap="round" opacity="0.8"';
  final b = StringBuffer();
  for (final s in [-1.0, 1.0]) {
    b.write('<path d="M ${n(s * 0.34)} -0.96 Q ${n(s * 0.44)} -0.78 ${n(s * 0.62)} -0.74" $st/>'
        '<path d="M ${n(s * 0.5)} -0.9 Q ${n(s * 0.62)} -0.72 ${n(s * 0.8)} -0.62" $st/>');
    // 눈꼬리에서 뻗는 선
    b.write('<path d="M ${n(s * 0.6)} -0.12 Q ${n(s * 0.74)} -0.16 ${n(s * 0.86)} -0.28" $st/>');
  }
  return b.toString();
}

String _rosettes(String fur, String c) {
  final inner = mix(fur, c, 0.35);
  const spots = [
    (-0.62, -0.34, 0.1), (0.62, -0.38, 0.09), (-0.8, 0.02, 0.08), (0.8, 0.06, 0.09),
    (-0.46, -0.78, 0.07), (0.44, -0.8, 0.07), (-0.86, -0.3, 0.06), (0.88, -0.24, 0.06),
    (-0.74, 0.34, 0.07), (0.72, 0.38, 0.06),
  ];
  return spots
      .map((p) => '<ellipse cx="${n(p.$1)}" cy="${n(p.$2)}" rx="${n(p.$3 * 1.15)}" ry="${n(p.$3)}" '
          'fill="#$inner" stroke="#$c" stroke-width="${n(p.$3 * 0.42)}" opacity="0.9"/>')
      .join();
}

String _ribbon(String line) => '<g transform="translate(-0.6 -0.84) rotate(-22)" stroke="#$line" stroke-width="0.03">'
    '<ellipse cx="-0.14" cy="0" rx="0.16" ry="0.11" fill="#ff8fb1"/>'
    '<ellipse cx="0.14" cy="0" rx="0.16" ry="0.11" fill="#ff8fb1"/>'
    '<path d="M -0.05 0.04 L -0.12 0.2 M 0.05 0.04 L 0.12 0.2" stroke="#ff6f9a" stroke-width="0.05" stroke-linecap="round"/>'
    '<circle r="0.065" fill="#ff6f9a"/></g>';

String _flower(String line) => '<g transform="translate(0.56 -0.78)">'
    '${[for (var i = 0; i < 5; i++) i].map((i) => '<circle cx="${n(cos(i * 2 * pi / 5 - pi / 2) * 0.11)}" cy="${n(sin(i * 2 * pi / 5 - pi / 2) * 0.11)}" r="0.09" fill="#ffb3c7" stroke="#$line" stroke-width="0.025"/>').join()}'
    '<circle r="0.07" fill="#ffd35c" stroke="#$line" stroke-width="0.025"/></g>';

String _crown() => '<g transform="translate(0 -1.02)" stroke="#8a5a10" stroke-width="0.04" stroke-linejoin="round">'
    '<path d="M -0.34 0.1 L -0.38 -0.26 L -0.18 -0.08 L 0 -0.34 L 0.18 -0.08 L 0.38 -0.26 L 0.34 0.1 Z" fill="url(#gold)"/>'
    '<circle cx="0" cy="-0.02" r="0.055" fill="#e0525f" stroke-width="0.025"/>'
    '<circle cx="-0.22" cy="0.02" r="0.035" fill="#6aa8e8" stroke-width="0.02"/>'
    '<circle cx="0.22" cy="0.02" r="0.035" fill="#6aa8e8" stroke-width="0.02"/></g>';

String _heartPath(double x, double y, double s) => 'M ${n(x)} ${n(y + s * 0.9)} '
    'C ${n(x - s * 1.4)} ${n(y + s * 0.1)} ${n(x - s * 0.7)} ${n(y - s)} ${n(x)} ${n(y - s * 0.35)} '
    'C ${n(x + s * 0.7)} ${n(y - s)} ${n(x + s * 1.4)} ${n(y + s * 0.1)} ${n(x)} ${n(y + s * 0.9)} Z';

// ---------------------------------------------------------------- 얼굴

String face(int t, String f) {
  final b = breeds[t];
  final g = _geo(b);
  final dark = isDark(t);
  final eyeInk = dark ? 'f1e6d6' : _ink;
  final furLum = _lum(b.coats.first.fur);

  final defs = StringBuffer();
  void iris(String id, (String, String) c) => defs.write(
      '<linearGradient id="$id" x1="0" y1="0" x2="0" y2="1">'
      '<stop offset="0" stop-color="#${c.$1}"/><stop offset="1" stop-color="#${c.$2}"/></linearGradient>');
  iris('irisL', b.eyes);
  iris('irisR', b.eyes2 ?? b.eyes);

  final o = StringBuffer();

  // 볼터치 + 빗금
  final by = g.eyeY + 0.3;
  final blushOpacity = f == 'content' || f == 'love' ? 0.75 : 0.55;
  for (final s in [-1.0, 1.0]) {
    o.write('<ellipse cx="${n(s * 0.66)}" cy="${n(by)}" rx="0.19" ry="0.11" fill="#ff8f9c" opacity="$blushOpacity"/>');
    for (var i = 0; i < 3; i++) {
      final x = s * 0.66 + (i - 1) * 0.07;
      o.write('<path d="M ${n(x - 0.02)} ${n(by + 0.04)} l 0.04 -0.075" stroke="#ef6e80" '
          'stroke-width="0.022" stroke-linecap="round" opacity="0.75"/>');
    }
  }

  // 눈
  for (final s in [-1.0, 1.0]) {
    var kind = f;
    if (f == 'wink' && s > 0) kind = 'happy';
    o.write(_eye(kind, s * g.eyeX, g.eyeY, s, g, eyeInk, dark, s < 0 ? 'irisL' : 'irisR'));
  }

  // 코 + 인중
  final ny = g.noseY, my = g.mouthY;
  o.write('<path d="M -0.085 ${n(ny - 0.04)} Q 0 ${n(ny - 0.09)} 0.085 ${n(ny - 0.04)} '
      'Q 0.035 ${n(ny + 0.05)} 0 ${n(ny + 0.05)} Q -0.035 ${n(ny + 0.05)} -0.085 ${n(ny - 0.04)} Z" '
      'fill="#${b.nose}" stroke="#${mix(b.nose, _ink, 0.35)}" stroke-width="0.015"/>'
      '<ellipse cx="-0.025" cy="${n(ny - 0.035)}" rx="0.028" ry="0.016" fill="#ffffff" opacity="0.7"/>');

  final mouthLine = 'fill="none" stroke="#$_ink" stroke-width="0.042" stroke-linecap="round" stroke-linejoin="round"';
  final omega = 'M -0.16 ${n(my)} Q -0.08 ${n(my + 0.11)} 0 ${n(my + 0.015)} '
      'Q 0.08 ${n(my + 0.11)} 0.16 ${n(my)}';
  final philtrum = '<path d="M 0 ${n(ny + 0.04)} V ${n(my + 0.015)}" $mouthLine/>';
  switch (f) {
    case 'surprised':
      o.write('$philtrum<ellipse cx="0" cy="${n(my + 0.09)}" rx="0.055" ry="0.065" fill="#c9505f"/>');
    case 'smile' || 'happy' || 'love':
      o.write('<path d="M -0.11 ${n(my + 0.05)} Q 0 ${n(my + 0.25)} 0.11 ${n(my + 0.05)} Z" fill="#c9505f"/>'
          '<ellipse cx="0" cy="${n(my + 0.15)}" rx="0.055" ry="0.035" fill="#f59aa6"/>'
          '$philtrum<path d="$omega" $mouthLine/>');
    case 'bleh':
      o.write('$philtrum<path d="$omega" $mouthLine/>'
          '<path d="M -0.07 ${n(my + 0.05)} Q -0.08 ${n(my + 0.26)} 0 ${n(my + 0.27)} '
          'Q 0.08 ${n(my + 0.26)} 0.07 ${n(my + 0.05)} Z" fill="#f58a9a" stroke="#d9606e" stroke-width="0.022"/>'
          '<path d="M 0 ${n(my + 0.08)} v 0.12" stroke="#d9606e" stroke-width="0.018" stroke-linecap="round"/>');
    default:
      o.write('$philtrum<path d="$omega" $mouthLine/>');
  }

  // 수염 3가닥
  final whisker = furLum > 0.6
      ? 'stroke="#$_ink" opacity="0.3"'
      : 'stroke="#ffffff" opacity="0.75"';
  for (final s in [-1.0, 1.0]) {
    for (var i = 0; i < 3; i++) {
      final y0 = my - 0.07 + i * 0.07;
      final y1 = my - 0.2 + i * 0.16;
      o.write('<path d="M ${n(s * 0.46)} ${n(y0)} Q ${n(s * 0.9)} ${n((y0 + y1) / 2 - 0.02)} ${n(s * 1.3)} ${n(y1)}" '
          'fill="none" $whisker stroke-width="0.022" stroke-linecap="round"/>');
    }
  }

  // 덤
  if (f == 'sleepy') {
    o.write('<path d="M 0.66 -1.02 h 0.15 l -0.15 0.17 h 0.15 M 0.94 -1.26 h 0.11 l -0.11 0.13 h 0.11" '
        'fill="none" stroke="#8a8178" stroke-width="0.04" stroke-linecap="round" stroke-linejoin="round"/>');
  }
  if (f == 'surprised') {
    o.write('<path d="M 0.9 -0.62 Q 0.79 -0.46 0.83 -0.38 Q 0.9 -0.32 0.97 -0.38 Q 1.01 -0.46 0.9 -0.62 Z" '
        'fill="#9fdcff" stroke="#4aa3d8" stroke-width="0.022"/>');
  }
  return _svg(defs.toString(), o.toString());
}

String _eye(String kind, double cx, double cy, double side, _Geo g, String ink,
    bool dark, String irisId) {
  final line = 'fill="none" stroke="#$ink" stroke-width="0.06" stroke-linecap="round" stroke-linejoin="round"';
  final outer = cx + side * 0.15;
  switch (kind) {
    case 'sleepy' || 'content' || 'blink':
      return '<path d="M ${n(cx - 0.15)} ${n(cy)} Q ${n(cx)} ${n(cy + 0.13)} ${n(cx + 0.15)} ${n(cy)}" $line/>'
          '<path d="M ${n(outer)} ${n(cy)} l ${n(side * 0.05)} -0.03" $line/>';
    case 'happy':
      return '<path d="M ${n(cx - 0.15)} ${n(cy + 0.05)} Q ${n(cx)} ${n(cy - 0.14)} ${n(cx + 0.15)} ${n(cy + 0.05)}" $line/>';
    case 'bleh':
      final d = side < 0
          ? 'M ${n(cx - 0.13)} ${n(cy - 0.11)} L ${n(cx + 0.11)} ${n(cy)} L ${n(cx - 0.13)} ${n(cy + 0.11)}'
          : 'M ${n(cx + 0.13)} ${n(cy - 0.11)} L ${n(cx - 0.11)} ${n(cy)} L ${n(cx + 0.13)} ${n(cy + 0.11)}';
      return '<path d="$d" $line/>';
    case 'surprised':
      return '<circle cx="${n(cx)}" cy="${n(cy)}" r="0.17" fill="#ffffff" stroke="#$_eyeLine" stroke-width="0.045"/>'
          '<circle cx="${n(cx)}" cy="${n(cy + 0.02)}" r="0.07" fill="#$_eyeLine"/>'
          '<circle cx="${n(cx + 0.03)}" cy="${n(cy - 0.01)}" r="0.022" fill="#ffffff"/>';
    case 'love':
      return '<path d="${_heartPath(cx, cy, 0.18)}" fill="#ff5f7e" stroke="#c93a5a" stroke-width="0.025"/>'
          '<ellipse cx="${n(cx - 0.06)}" cy="${n(cy - 0.05)}" rx="0.045" ry="0.03" fill="#ffffff" opacity="0.85"/>';
    case 'proud':
      return '<path d="M ${n(cx - 0.16)} ${n(cy - 0.02)} A 0.16 0.17 0 0 0 ${n(cx + 0.16)} ${n(cy - 0.02)} Z" fill="url(#$irisId)"/>'
          '<path d="M ${n(cx - 0.05)} ${n(cy - 0.02)} A 0.05 0.12 0 0 0 ${n(cx + 0.05)} ${n(cy - 0.02)} Z" fill="#1a1210"/>'
          '<path d="M ${n(cx - 0.19)} ${n(cy - 0.03)} L ${n(cx + 0.19)} ${n(cy - 0.07)}" '
          'fill="none" stroke="#$_eyeLine" stroke-width="0.06" stroke-linecap="round"/>'
          '<circle cx="${n(cx + 0.06)}" cy="${n(cy + 0.04)}" r="0.035" fill="#ffffff"/>';
    default:
      final big = kind == 'sparkle';
      final w = g.eyeW * (big ? 1.12 : 1.0), h = g.eyeH * (big ? 1.1 : 1.0);
      final ring = '1a1210';
      final b = StringBuffer()
        // 눈동자 + 테두리
        ..write('<ellipse cx="${n(cx)}" cy="${n(cy)}" rx="${n(w / 2)}" ry="${n(h / 2)}" '
            'fill="url(#$irisId)" stroke="#$_eyeLine" stroke-width="0.035"/>')
        // 동공 (크고 동그랗게)
        ..write('<ellipse cx="${n(cx)}" cy="${n(cy + h * 0.02)}" rx="${n(w * 0.27)}" ry="${n(h * 0.32)}" fill="#$ring"/>')
        // 아래쪽 반사광
        ..write('<ellipse cx="${n(cx)}" cy="${n(cy + h * 0.3)}" rx="${n(w * 0.3)}" ry="${n(h * 0.1)}" '
            'fill="#ffffff" opacity="0.28"/>')
        // 윗눈꺼풀 선 + 눈꼬리
        ..write('<path d="M ${n(cx - w / 2 - 0.01)} ${n(cy - h * 0.05)} Q ${n(cx)} ${n(cy - h * 0.7)} '
            '${n(cx + w / 2 + 0.01)} ${n(cy - h * 0.05)}" fill="none" stroke="#$_eyeLine" '
            'stroke-width="0.05" stroke-linecap="round"/>')
        ..write('<path d="M ${n(cx + side * w / 2)} ${n(cy - h * 0.1)} l ${n(side * 0.06)} -0.05" '
            'fill="none" stroke="#$_eyeLine" stroke-width="0.045" stroke-linecap="round"/>');
      if (big) {
        b.write('<path d="${_sparkle(cx + w * 0.17, cy - h * 0.18, 0.1)}" fill="#ffffff"/>'
            '<circle cx="${n(cx + w * 0.3)}" cy="${n(cy + h * 0.14)}" r="${n(w * 0.06)}" fill="#ffffff"/>');
      } else {
        b.write('<circle cx="${n(cx + w * 0.17)}" cy="${n(cy - h * 0.18)}" r="${n(w * 0.21)}" fill="#ffffff"/>');
      }
      b.write('<circle cx="${n(cx - w * 0.18)}" cy="${n(cy + h * 0.17)}" r="${n(w * 0.085)}" fill="#ffffff"/>');
      return b.toString();
  }
}

/// 네 갈래 반짝이.
String _sparkle(double x, double y, double k) => 'M ${n(x)} ${n(y - k)} '
    'Q ${n(x + k * 0.18)} ${n(y - k * 0.18)} ${n(x + k)} ${n(y)} '
    'Q ${n(x + k * 0.18)} ${n(y + k * 0.18)} ${n(x)} ${n(y + k)} '
    'Q ${n(x - k * 0.18)} ${n(y + k * 0.18)} ${n(x - k)} ${n(y)} '
    'Q ${n(x - k * 0.18)} ${n(y - k * 0.18)} ${n(x)} ${n(y - k)} Z';
