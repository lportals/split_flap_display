import 'dart:async';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Procedural, density-aware sound engine for the Split-Flap display.
///
/// ## Architecture
/// Uses a **polyphonic player pool** for overlapping click sounds and a
/// **single looping player** for the ambient "rain" texture. All audio
/// parameters are computed from one value: **global density** (ratio of
/// active flipping characters to total board capacity).
///
/// ## Web Audio Policy
/// Browsers block audio until a user gesture triggers playback. This engine
/// does NOT use a manual "unlock" step. Instead, every `play()` call is
/// wrapped in a silent `catchError`. Before the first gesture, plays fail
/// silently (the board animates without sound). The instant the user taps
/// anywhere, the browser's AudioContext auto-resumes and all subsequent
/// plays succeed — no overlay, no extra button.
///
/// ## Hard-Stop Contract
/// When the last row reports `activeChars = 0`, the engine **immediately
/// mutes** the rain loop (volume → 0) and pauses it after a 400 ms grace
/// period. This guarantees dead silence when the board is idle.
///
/// ## Integration
/// ```dart
/// // Row widget (every animation cycle):
/// FlapSoundManager.instance.updateRowActivity(rowHashCode, activeCount);
/// FlapSoundManager.instance.playClick();
///
/// // Host screen:
/// FlapSoundManager.instance.init();      // initState (preload only)
/// FlapSoundManager.instance.dispose();   // dispose
/// ```
class FlapSoundManager {
  FlapSoundManager._();
  static final FlapSoundManager instance = FlapSoundManager._();

  // ---------------------------------------------------------------------------
  // Configuration — adjust these if the board layout changes.
  // ---------------------------------------------------------------------------

  /// Max characters that could flip simultaneously on a full board.
  static const int maxBoardCapacity = 450;

  /// Number of pre-loaded click players in the round-robin pool.
  static const int _poolSize = 4;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _isInitialized = false;

  /// Per-row activity tracker: `rowId → active char count`.
  final Map<int, int> _rowActivity = {};
  int _activeUnits = 0;

  DateTime _lastAmbientUpdateTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ---------------------------------------------------------------------------
  // Players
  // ---------------------------------------------------------------------------

  final List<AudioPlayer> _clickPool = [];
  int _nextClickIndex = 0;

  final AudioPlayer _rainPlayer = AudioPlayer();
  Timer? _stopTimer;
  Timer? _clickPulseTimer;
  bool _clickRequested = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Preloads all audio assets. Does NOT play anything.
  /// Safe to call multiple times (idempotent).
  Future<void> init() async {
    if (_isInitialized) return;

    // Detect mobile platform (Android/iOS)
    // ignore: unused_local_variable
    final isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    
    // Audio is now optimized for mobile via the Accumulator Pattern 
    // and rebuild isolation in the UI.

    try {
      for (int i = 0; i < _poolSize; i++) {
        final player = AudioPlayer();
        await player.setAsset('assets/audio/flap_single.mp3', preload: true);
        await player.setVolume(0);
        _clickPool.add(player);
      }
      await _rainPlayer.setAsset('assets/audio/flap_rain_loop.mp3', preload: true);
      await _rainPlayer.setLoopMode(LoopMode.one);
      await _rainPlayer.setVolume(0);
      
      // Start the click accumulator pulse (20Hz loop for clicks)
      _clickPulseTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (_clickRequested && _isInitialized) {
          _clickRequested = false;
          _dispatchRealClick();
        }
      });

      _isInitialized = true;
    } catch (_) {
      // Audio is non-critical; never crash the UI.
    }
  }

  /// Reports current activity for a specific row.
  ///
  /// When a row finishes all its flips, it MUST call this with
  /// `activeChars = 0` to signal completion. The engine uses these
  /// reports to compute global density and will hard-stop all audio
  /// when every row reports zero.
  void updateRowActivity(int rowId, int activeChars) {
    if (!_isInitialized) return;

    final int oldVal = _rowActivity[rowId] ?? 0;
    if (activeChars > 0) {
      _rowActivity[rowId] = activeChars;
    } else {
      _rowActivity.remove(rowId);
    }

    _activeUnits += (activeChars - oldVal);
    // Hard clamp to zero just in case of weird drift
    if (_activeUnits < 0) _activeUnits = 0;

    _updateAmbientMix();
  }

  /// Fires a single mechanical click from the polyphonic pool.
  ///
  /// Every call is wrapped in catchError so the engine never crashes.
  /// Before the browser AudioContext is unlocked (no user gesture yet),
  /// plays fail silently. After the first gesture, they succeed.
  ///
  /// Applies a density-based throttle and inverse volume curve so clicks
  /// remain crisp when sparse and merge into a "brrrr" when dense.
  /// Signals that a click should ideally be played.
  /// The manager will decide if it actually plays it based on its own timing pulse
  /// to avoid overwhelming the platform channel (Accumulator Pattern).
  void playClick() {
    _clickRequested = true;
  }

  /// Internal: Actually sends a single click event to the hardware/engine.
  /// This is called MUCH less frequently than playClick() to avoid jank.
  void _dispatchRealClick() {
    if (!_isInitialized) return;

    final double density = (_activeUnits / maxBoardCapacity).clamp(0.0, 1.0);
    // Inverse volume: sparse is loud, dense is attenuated (the rain loop provides the mass)
    final double vol = 0.7 * math.pow(1.0 - (density * 0.5), 1.3);

    final player = _clickPool[_nextClickIndex];
    _nextClickIndex = (_nextClickIndex + 1) % _poolSize;

    try {
      player.setVolume(vol.clamp(0.0, 1.0)).catchError((_) => null);
      player.seek(Duration.zero).catchError((_) => null);
      player.play().catchError((_) => null);
    } catch (_) {}
  }

  /// Triggers haptic feedback. Throttled to preserve UI thread budget.
  /// Note: Currently disabled on WEB due to inconsistent synchronous overhead.
  void playHaptic() {
    // Disabled on Web to maximize animation performance
    return;
  }

  /// Releases all player resources.
  void dispose() {
    _clickPulseTimer?.cancel();
    _stopTimer?.cancel();
    for (final p in _clickPool) {
      p.dispose();
    }
    _rainPlayer.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal — Ambient Mix
  // ---------------------------------------------------------------------------

  /// Recalculates the rain-loop volume and playback speed based on density.
  ///
  /// ### Hard-Stop
  /// When `_activeUnits == 0`:
  ///   1. Volume is set to 0 **immediately** (instant silence).
  ///   2. A 400 ms timer pauses the player (avoids start/stop thrashing
  ///      if a new shuffle begins within that window).
  void _updateAmbientMix() {
    if (!_isInitialized) return;

    final now = DateTime.now();
    // Maximum 10 ambient updates per second (100ms throttle).
    // The rain loop is a texture; it doesn't need high-frequency updates.
    if (now.difference(_lastAmbientUpdateTime).inMilliseconds < 100 && _activeUnits > 0) return;
    _lastAmbientUpdateTime = now;

    final double density = (_activeUnits / maxBoardCapacity).clamp(0.0, 1.0);

    // ==== ALL UNITS STOPPED → STOP RAIN LOOP ====
    if (_activeUnits == 0) {
      _stopTimer?.cancel();
      _stopTimer = null;

      _rainPlayer.setVolume(0).catchError((_) => null);
      _rainPlayer.stop().catchError((_) => null);
      return;
    }

    // ==== ACTIVE UNITS → ADJUST MIX ====
    _stopTimer?.cancel();
    _stopTimer = null;

    final double loopVol = (math.pow(density, 0.4) * 0.75 + 0.08).clamp(0.0, 1.0);
    final double speed = (0.96 + (density * 0.28)).clamp(0.5, 2.0);

    try {
      if (!_rainPlayer.playing) {
          _rainPlayer.seek(Duration.zero).catchError((_) => null);
          _rainPlayer.play().catchError((_) => null);
      }
      _rainPlayer.setVolume(loopVol).catchError((_) => null);
      _rainPlayer.setSpeed(speed).catchError((_) => null);
    } catch (_) {}
  }
}
