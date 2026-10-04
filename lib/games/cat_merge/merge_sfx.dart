import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// 냥냥 합체 효과음. assets/audio/*.wav (tool/gen_sfx.dart 로 합성).
///
/// 소리가 한꺼번에 몰려도 시끄럽지 않게 종류별로 최소 간격을 둔다.
/// 재생 실패(기기 오디오 문제 등)는 게임을 멈추지 않도록 삼킨다.
abstract final class Sfx {
  static bool enabled = true;

  static final _pools = <String, AudioPool>{};
  static final _last = <String, DateTime>{};
  static bool _loading = false;

  /// 자주 겹쳐 나는 소리는 풀로 미리 준비한다.
  static const _pooled = {
    'pop.wav': 5, 'drop.wav': 3, 'tick.wav': 2, 'crack.wav': 3, 'thud.wav': 2,
  };
  static const _all = [
    'pop.wav', 'pop_big.wav', 'drop.wav', 'chain1.wav', 'chain2.wav',
    'chain3.wav', 'chain4.wav', 'chain5.wav', 'meow.wav', 'meow_hi.wav',
    'meow_low.wav', 'churu.wav', 'boing.wav', 'puff.wav', 'roar.wav',
    'fanfare.wav', 'tick.wav', 'codex.wav', 'gameover.wav',
    // 냥냥 새총
    'launch.wav', 'thud.wav', 'crack.wav', 'squeak.wav', 'boom.wav',
  ];

  static Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      await FlameAudio.audioCache.loadAll(_all);
      for (final e in _pooled.entries) {
        _pools[e.key] =
            await FlameAudio.createPool(e.key, maxPlayers: e.value);
      }
    } catch (e) {
      debugPrint('Sfx.load failed: $e');
    }
  }

  static void _play(String file, {double volume = 1, int gapMs = 40}) {
    if (!enabled) return;
    final now = DateTime.now();
    final last = _last[file];
    if (last != null && now.difference(last).inMilliseconds < gapMs) return;
    _last[file] = now;
    final pool = _pools[file];
    final f = pool != null
        ? pool.start(volume: volume)
        : FlameAudio.play(file, volume: volume);
    f.catchError((Object e) {
      debugPrint('Sfx $file failed: $e');
      return pool != null ? () async {} : AudioPlayer();
    });
  }

  static void drop() => _play('drop.wav', volume: 0.5);

  /// 합체. 큰 고양이일수록 묵직한 소리.
  static void merge(int tier) =>
      tier >= 6 ? _play('pop_big.wav', volume: 0.9) : _play('pop.wav', volume: 0.8);

  /// 연쇄 음계 + 냐옹.
  static void chain(int chain) {
    if (chain < 2) return;
    // 연쇄 2 → chain1.wav ... 연쇄 6 이상 → chain5.wav
    _play('chain${(chain - 1).clamp(1, 5)}.wav', volume: 0.8, gapMs: 90);
    meow(chain >= 4 ? 'meow_hi.wav' : 'meow.wav');
  }

  static void meow([String file = 'meow.wav']) =>
      _play(file, volume: 0.85, gapMs: 260);

  static void churu() {
    _play('churu.wav', volume: 0.9, gapMs: 300);
    meow('meow_hi.wav');
  }

  static void cucumber() {
    _play('boing.wav', volume: 0.9, gapMs: 200);
    meow('meow_hi.wav');
  }

  static void fluff() {
    _play('puff.wav', volume: 0.9, gapMs: 200);
    meow('meow_low.wav');
  }

  static void roar() => _play('roar.wav', gapMs: 400);
  static void fanfare() => _play('fanfare.wav', volume: 0.8, gapMs: 400);
  static void tick() => _play('tick.wav', volume: 0.6, gapMs: 300);
  static void codex() => _play('codex.wav', volume: 0.7, gapMs: 200);
  // 냥냥 새총
  static void launch() => _play('launch.wav', volume: 0.8, gapMs: 200);
  static void thud() => _play('thud.wav', volume: 0.6, gapMs: 80);
  static void crack() => _play('crack.wav', volume: 0.7, gapMs: 60);
  static void squeak() => _play('squeak.wav', volume: 0.9, gapMs: 120);
  static void boom() => _play('boom.wav', volume: 0.9, gapMs: 200);

  static void gameOver() => _play('gameover.wav', volume: 0.8, gapMs: 1000);
}
