// 냥냥 합체 효과음 합성기 (녹음 없이 수식으로 만든다).
//
//   dart run tool/gen_sfx.dart
//
// assets/audio/*.wav (22.05kHz, 16bit, mono) 를 만든다.
// 실제 녹음/유료 음원으로 바꿀 때는 같은 파일명으로 덮어쓰면 된다.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const rate = 22050;
final _rng = Random(7);

void main() {
  final dir = Directory('assets/audio')..createSync(recursive: true);
  final sounds = <String, List<double>>{
    'pop.wav': pop(900, 480, 0.08),
    'pop_big.wav': mixAll([pop(420, 170, 0.16), thump(0.18, 0.6)]),
    'drop.wav': mixAll([noiseBurst(0.06, 0.25, cutoff: 0.08), pop(320, 260, 0.05, gain: 0.35)]),
    for (var k = 1; k <= 5; k++) 'chain$k.wav': chime(k),
    'meow.wav': meow(1.0, 0.42),
    'meow_hi.wav': meow(1.4, 0.26),
    'meow_low.wav': meow(0.68, 0.55),
    'churu.wav': churu(),
    'boing.wav': boing(),
    'puff.wav': mixAll([noiseBurst(0.35, 0.55, cutoff: 0.05), thump(0.3, 0.7)]),
    'roar.wav': roar(),
    'fanfare.wav': fanfare(),
    'tick.wav': tone(1046, 0.07, gain: 0.5, shape: _square),
    'codex.wav': mixAll([bell(1318, 0.35, 0), bell(1760, 0.45, 0.08)]),
    'gameover.wav': gameOver(),
  };
  for (final e in sounds.entries) {
    File('${dir.path}/${e.key}').writeAsBytesSync(wav(normalize(e.value)));
  }
  stdout.writeln('wrote ${sounds.length} sounds to ${dir.path}');
}

// ---------------------------------------------------------------- 기본 재료

typedef Shape = double Function(double phase);
double _sine(double p) => sin(2 * pi * p);
double _square(double p) => (p % 1) < 0.5 ? 0.6 : -0.6;
double _tri(double p) => 1 - 4 * ((p % 1) - 0.5).abs();

List<double> _buf(double seconds) => List.filled((seconds * rate).round(), 0.0);

/// 빠르게 올라가고 지수적으로 줄어드는 소리 모양.
double _env(double t, double len, {double attack = 0.004, double curve = 5}) {
  if (t < attack) return t / attack;
  return exp(-curve * (t - attack) / len);
}

List<double> tone(double f, double len,
    {double gain = 1, Shape shape = _sine, double delay = 0}) {
  final out = _buf(len + delay);
  var ph = 0.0;
  for (var i = (delay * rate).round(); i < out.length; i++) {
    final t = i / rate - delay;
    ph += f / rate;
    out[i] = shape(ph) * _env(t, len) * gain;
  }
  return out;
}

/// 음높이가 f0→f1 로 떨어지는 "뿅".
List<double> pop(double f0, double f1, double len, {double gain = 1}) {
  final out = _buf(len);
  var ph = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / rate, k = t / len;
    final f = f0 * pow(f1 / f0, k).toDouble();
    ph += f / rate;
    out[i] = (sin(2 * pi * ph) + 0.3 * sin(4 * pi * ph)) * _env(t, len, curve: 4) * gain;
  }
  return out;
}

List<double> thump(double len, double gain) => pop(120, 45, len, gain: gain);

/// 저역 통과한 잡음 (cutoff 0~1, 작을수록 뭉툭).
List<double> noiseBurst(double len, double gain, {double cutoff = 0.2}) {
  final out = _buf(len);
  var y = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / rate;
    y += cutoff * ((_rng.nextDouble() * 2 - 1) - y);
    out[i] = y * 3 * _env(t, len, attack: 0.01, curve: 3) * gain;
  }
  return out;
}

/// 종소리 (비정수배 배음).
List<double> bell(double f, double len, double delay, {double gain = 0.8}) {
  final out = _buf(len + delay);
  for (var i = (delay * rate).round(); i < out.length; i++) {
    final t = i / rate - delay;
    final e = _env(t, len, attack: 0.002, curve: 4);
    out[i] = (sin(2 * pi * f * t) + 0.35 * sin(2 * pi * f * 2.76 * t) * exp(-8 * t) +
            0.2 * sin(2 * pi * f * 5.4 * t) * exp(-14 * t)) *
        e *
        gain;
  }
  return out;
}

List<double> mixAll(List<List<double>> parts) {
  final out = _buf(parts.map((p) => p.length).reduce(max) / rate);
  for (final p in parts) {
    for (var i = 0; i < p.length; i++) {
      out[i] += p[i];
    }
  }
  return out;
}

List<double> normalize(List<double> s, {double peak = 0.85}) {
  final m = s.fold(0.0, (a, v) => max(a, v.abs()));
  return m == 0 ? s : [for (final v in s) v / m * peak];
}

Uint8List wav(List<double> s) {
  final data = ByteData(44 + s.length * 2);
  void str(int o, String v) {
    for (var i = 0; i < v.length; i++) {
      data.setUint8(o + i, v.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + s.length * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, s.length * 2, Endian.little);
  for (var i = 0; i < s.length; i++) {
    data.setInt16(44 + i * 2, (s[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

// ---------------------------------------------------------------- 효과음

/// 연쇄 k: 음이 k+1개 올라가는 종소리 (연쇄가 길수록 높고 길다).
List<double> chime(int k) {
  const scale = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3];
  return mixAll([
    for (var i = 0; i <= k; i++) bell(scale[min(i + k ~/ 2, scale.length - 1)], 0.3, i * 0.06),
  ]);
}

/// "냐옹": 음높이가 올라갔다 내려가고, 입 모양(포먼트)이 이-아-오로 바뀐다.
List<double> meow(double pitch, double len) {
  final out = _buf(len);
  var ph = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / rate, k = t / len;
    final contour = k < 0.3 ? 0.62 + k / 0.3 * 0.38 : 1.0 - (k - 0.3) / 0.7 * 0.42;
    final f0 = 800 * pitch * contour * (1 + 0.02 * sin(2 * pi * 6 * t));
    ph += f0 / rate;
    // 포먼트: 이(높은 F2) → 아(높은 F1) → 오(낮은 F1/F2)
    final f1 = k < 0.35 ? 450 + k / 0.35 * 550 : 1000 - (k - 0.35) / 0.65 * 450;
    final f2 = k < 0.35 ? 2300 - k / 0.35 * 800 : 1500 - (k - 0.35) / 0.65 * 600;
    var v = 0.0;
    for (var h = 1; h <= 14; h++) {
      final fh = f0 * h;
      final a = exp(-pow((fh - f1 * pitch) / 260, 2)) +
          0.6 * exp(-pow((fh - f2 * pitch) / 380, 2)) +
          0.25 * exp(-pow((fh - 3000 * pitch) / 500, 2)) +
          0.08 / h;
      v += a * sin(2 * pi * ph * h);
    }
    v += (_rng.nextDouble() * 2 - 1) * 0.03;
    final e = min(1.0, t / 0.03) * min(1.0, (len - t) / 0.12);
    out[i] = v * e;
  }
  return out;
}

/// 츄르: 빠르게 올라가는 반짝이 떨림.
List<double> churu() => mixAll([
      for (var i = 0; i < 12; i++) bell(880 * pow(2, i / 7).toDouble(), 0.22, i * 0.035, gain: 0.5 + i * 0.03),
      tone(1760, 0.5, gain: 0.15, shape: _tri, delay: 0.3),
    ]);

/// 오이: 용수철 "뾰잉".
List<double> boing() {
  const len = 0.45;
  final out = _buf(len);
  var ph = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / rate;
    final f = 220 + 380 * (t / len) + 160 * sin(2 * pi * 14 * t) * exp(-5 * t);
    ph += f / rate;
    out[i] = (sin(2 * pi * ph) + 0.25 * _tri(ph * 2)) * _env(t, len, attack: 0.005, curve: 3);
  }
  return out;
}

/// 사자 포효: 낮은 톱니 + 거친 잡음, 점점 커졌다 사라진다.
List<double> roar() {
  const len = 0.95;
  final out = _buf(len);
  var ph = 0.0, y = 0.0;
  for (var i = 0; i < out.length; i++) {
    final t = i / rate, k = t / len;
    final f = 110 - 40 * k;
    ph += f / rate;
    final saw = 2 * (ph % 1) - 1;
    y += 0.06 * ((_rng.nextDouble() * 2 - 1) - y);
    final growl = 0.6 + 0.4 * sin(2 * pi * 28 * t);
    final e = sin(pi * min(1.0, k * 1.4)).clamp(0.0, 1.0) * (k > 0.7 ? (1 - k) / 0.3 : 1);
    out[i] = (saw * 0.6 + y * 4) * growl * e;
  }
  return out;
}

/// 팡파르: 도-미-솔-도 + 화음.
List<double> fanfare() => mixAll([
      for (final (i, f) in [(0, 523.3), (1, 659.3), (2, 784.0), (3, 1046.5)])
        tone(f, 0.25, gain: 0.5, shape: _square, delay: i * 0.1),
      for (final f in [523.3, 659.3, 784.0, 1046.5]) tone(f, 0.8, gain: 0.3, shape: _tri, delay: 0.42),
    ]);

List<double> gameOver() => mixAll([
      for (final (i, f) in [(0, 784.0), (1, 659.3), (2, 523.3), (3, 392.0)])
        tone(f, 0.35, gain: 0.5, shape: _tri, delay: i * 0.16),
    ]);
