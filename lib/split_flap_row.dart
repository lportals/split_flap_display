import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'flap_sound_manager.dart';

/// A high-performance row of split-flap units that uses Shared Sprite Sheets (textures).
/// This is the most stable and performant method for Flutter Web CanvasKit/WASM.
/// It creates ONE single sprite sheet per size to avoid engine context loss crashes.
class SplitFlapRow extends StatefulWidget {
  final String text;
  final int maxLength;
  final double unitWidth;
  final double unitHeight;
  final double spacing;
  final Color flapColor;
  final Color textColor;
  final Duration flipDuration;

  /// When true, this row does NOT report activity to [FlapSoundManager]
  /// and does NOT trigger click sounds. Use for decorative rows like
  /// the header clock that should animate silently.
  final bool silent;

  const SplitFlapRow({
    super.key,
    required this.text,
    this.maxLength = 10,
    this.unitWidth = 20,
    this.unitHeight = 34,
    this.spacing = 2,
    this.flapColor = const Color(0xFF161616),
    this.textColor = Colors.white,
    this.flipDuration = const Duration(milliseconds: 75),
    this.silent = false,
  });

  @override
  State<SplitFlapRow> createState() => _SplitFlapRowState();
}

const String alphabet = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:-";

class _SplitFlapRowState extends State<SplitFlapRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<int> _currentIndices;
  late List<int> _targetIndices;
  late List<int> _remainingSteps;

  static final Map<String, ui.Image> _spriteSheets = {};
  static final Map<String, Future<ui.Image>> _pendingSpriteSheets = {};

  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _currentIndices = List.generate(widget.maxLength, (i) => 0);
    _targetIndices = List.generate(widget.maxLength, (i) => 0);
    _remainingSteps = List.generate(widget.maxLength, (i) => 0);

    _controller = AnimationController(vsync: this, duration: widget.flipDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onCycleComplete();
        }
      });

    _startWarmup();
    _updateTargets(widget.text);
    
    if (_remainingSteps.any((s) => s > 0) && _isReady) {
      _controller.forward();
    }
  }

  Future<void> _startWarmup() async {
    final String colorKey = widget.textColor.value.toString();
    final String key = "${widget.unitWidth.toInt()}-${widget.unitHeight.toInt()}-$colorKey";
    
    if (_spriteSheets.containsKey(key)) {
        if (mounted) setState(() => _isReady = true);
        return;
    }

    if (_pendingSpriteSheets.containsKey(key)) {
        await _pendingSpriteSheets[key];
    } else {
        final renderFuture = _renderSpriteSheet();
        _pendingSpriteSheets[key] = renderFuture;
        final img = await renderFuture;
        _spriteSheets[key] = img;
        _pendingSpriteSheets.remove(key);
    }

    if (mounted) {
      setState(() => _isReady = true);
      if (_remainingSteps.any((s) => s > 0)) {
        _controller.forward();
      }
    }
  }

  Future<ui.Image> _renderSpriteSheet() async {
    const double pixelRatio = 2.0; 
    const int columns = 10;
    final int rows = (alphabet.length * 2 / columns).ceil();
    
    final int sheetW = (widget.unitWidth * columns * pixelRatio).toInt();
    final int sheetH = (widget.unitHeight / 2 * rows * pixelRatio).toInt();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    for (int i = 0; i < alphabet.length; i++) {
        final char = alphabet[i];
        _drawCharInSheet(canvas, char, true, i * 2, columns);
        _drawCharInSheet(canvas, char, false, i * 2 + 1, columns);
    }

    final picture = recorder.endRecording();
    return await picture.toImage(sheetW, sheetH);
  }

  void _drawCharInSheet(Canvas canvas, String char, bool isTop, int index, int columns) {
      final int row = index ~/ columns;
      final int col = index % columns;
      final double x = col * widget.unitWidth;
      final double y = row * (widget.unitHeight / 2);

      canvas.save();
      canvas.translate(x, y);

      final unitRect = Rect.fromLTWH(0, isTop ? 0 : -widget.unitHeight / 2, widget.unitWidth, widget.unitHeight);
      
      final Paint flapPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(widget.flapColor, Colors.white, 0.05)!,
            Color.lerp(widget.flapColor, Colors.black, 0.2)!,
          ],
        ).createShader(unitRect);

      final rRect = RRect.fromRectAndRadius(unitRect, const Radius.circular(3));
      
      canvas.clipRect(Rect.fromLTWH(0, 0, widget.unitWidth, widget.unitHeight / 2));
      canvas.drawRRect(rRect, flapPaint);

      if (isTop) {
          canvas.drawLine(
              const Offset(2, 0.5),
              Offset(widget.unitWidth - 2, 0.5),
              Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 0.5,
          );
      }
      
      canvas.drawRRect(rRect, Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0);

      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            color: widget.textColor,
            fontSize: widget.unitHeight * 0.72,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      
      final double textX = (widget.unitWidth - tp.width) / 2;
      // Precision centering: Use the actual ascent/descent box instead of just Height
      final double textY = (isTop ? 0 : -widget.unitHeight / 2) + (widget.unitHeight - tp.height) / 2;
      tp.paint(canvas, Offset(textX, textY));
      
      canvas.restore();
  }

  void _updateTargets(String newText) {
    final paddedText = newText.padRight(widget.maxLength).substring(0, widget.maxLength);
    for (int i = 0; i < widget.maxLength; i++) {
      final targetChar = paddedText[i].toUpperCase();
      final targetIdx = alphabet.indexOf(targetChar);
      _targetIndices[i] = (targetIdx == -1) ? 0 : targetIdx;
      
      // HARD GUARD: If it's a separator (colon or dot), force it to be static immediately.
      // This prevents the clock separator from "dancing" during minute changes.
      if (targetChar == ':' || targetChar == '.') {
        _currentIndices[i] = _targetIndices[i];
        _remainingSteps[i] = 0;
      } else {
        _remainingSteps[i] = (_targetIndices[i] - _currentIndices[i] + alphabet.length) % alphabet.length;
      }
    }
    
    // Notify activity to sound manager (only if this row is not silent)
    if (!widget.silent) {
      int active = _remainingSteps.where((s) => s > 0).length;
      FlapSoundManager.instance.updateRowActivity(hashCode, active);
    }
  }

  void _onCycleComplete() {
    bool wasActive = false;
    bool anyRemaining = false;
    for (int i = 0; i < widget.maxLength; i++) {
      if (_remainingSteps[i] > 0) {
        wasActive = true;
        _currentIndices[i] = (_currentIndices[i] + 1) % alphabet.length;
        _remainingSteps[i]--;
        if (_remainingSteps[i] > 0) anyRemaining = true;
      }
    }

    if (wasActive && !widget.silent) {
      // TRIGGER AUDIO:
      // We play a discrete click for detail.
      // The manager handles the background 'rain' volume based on global activity.
      FlapSoundManager.instance.playClick();
    }

    if (anyRemaining) {
      _controller.reset();
      _controller.forward();
      if (math.Random().nextDouble() > 0.6) {
        FlapSoundManager.instance.playHaptic();
      }
    } else {
      _controller.reset();
      if (mounted) setState(() {});
    }
    
    // Update local activity to the sound manager
    if (!widget.silent) {
      int active = _remainingSteps.where((s) => s > 0).length;
      FlapSoundManager.instance.updateRowActivity(hashCode, active);
    }
    // We only need to call setState if the animation stops.
    // Otherwise, the AnimatedBuilder will keep triggering repaints for the new cycle.
  }

  @override
  void didUpdateWidget(SplitFlapRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    bool needsUpdate = false;

    // 1. If maxLength changes, we MUST re-initialize the lists to avoid index out of bounds
    if (oldWidget.maxLength != widget.maxLength) {
      _currentIndices = List.generate(widget.maxLength, (i) => (i < _currentIndices.length) ? _currentIndices[i] : 0);
      _targetIndices = List.generate(widget.maxLength, (i) => (i < _targetIndices.length) ? _targetIndices[i] : 0);
      _remainingSteps = List.generate(widget.maxLength, (i) => (i < _remainingSteps.length) ? _remainingSteps[i] : 0);
      needsUpdate = true;
    }

    // 2. If text or maxLength changed, we update the targets
    if (needsUpdate || oldWidget.text != widget.text) {
      _updateTargets(widget.text);
      if (!_controller.isAnimating && _remainingSteps.any((s) => s > 0) && _isReady) {
        _controller.forward();
      }
    }
  }



  @override
  void dispose() {
    _controller.dispose();
    // CRITICAL: Notify the sound manager that this row is no longer active
    // before it is removed, to prevent "phantom" sounds.
    if (!widget.silent) {
      FlapSoundManager.instance.updateRowActivity(hashCode, 0);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return SizedBox(
      height: widget.unitHeight, 
      width: (widget.unitWidth * widget.maxLength) + (widget.spacing * (widget.maxLength - 1))
    );

    final String colorKey = widget.textColor.value.toString();
    final String key = "${widget.unitWidth.toInt()}-${widget.unitHeight.toInt()}-$colorKey";
    final sheet = _spriteSheets[key];
    if (sheet == null) return const SizedBox();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(
              (widget.unitWidth * widget.maxLength) + (widget.spacing * (widget.maxLength - 1)),
              widget.unitHeight,
            ),
            painter: SplitFlapRowPainter(
              animationValue: _controller.value,
              currentIndices: _currentIndices,
              remainingSteps: _remainingSteps,
              unitWidth: widget.unitWidth,
              unitHeight: widget.unitHeight,
              spacing: widget.spacing,
              spriteSheet: sheet,
            ),
          );
        },
      ),
    );
  }
}

class SplitFlapRowPainter extends CustomPainter {
  final double animationValue;
  final List<int> currentIndices;
  final List<int> remainingSteps;
  final double unitWidth;
  final double unitHeight;
  final double spacing;
  final ui.Image spriteSheet;

  SplitFlapRowPainter({
    required this.animationValue,
    required this.currentIndices,
    required this.remainingSteps,
    required this.unitWidth,
    required this.unitHeight,
    required this.spacing,
    required this.spriteSheet,
  });

  Rect _getCharRect(int charIndex, bool isTop) {
      final int index = charIndex * 2 + (isTop ? 0 : 1);
      const int columns = 10;
      final int row = index ~/ columns;
      final int col = index % columns;
      
      const double pixelRatio = 2.0; 
      return Rect.fromLTWH(
          col * unitWidth * pixelRatio, 
          row * (unitHeight / 2) * pixelRatio, 
          unitWidth * pixelRatio, 
          (unitHeight / 2) * pixelRatio
      );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint mainPaint = Paint();
    for (int i = 0; i < currentIndices.length; i++) {
        _drawUnit(canvas, i * (unitWidth + spacing), currentIndices[i], remainingSteps[i], mainPaint);
    }
  }

  void _drawUnit(Canvas canvas, double x, int currentIndex, int remaining, Paint paint) {
      final bool isActive = remaining > 0;
      final double val = isActive ? animationValue : 0.0;
      final double halfH = unitHeight / 2;

      // 1. STATIC OPTIMIZATION: If not moving, draw directly and stop.
      // This prevents "ghosting" from characters underneath.
      if (val < 0.001) {
        _drawHalf(canvas, Offset(x, 0), currentIndex, true, paint);
        _drawHalf(canvas, Offset(x, halfH), currentIndex, false, paint);
        
        final Paint hingeLinePaint = Paint()..color = Colors.black.withOpacity(0.6)..strokeWidth = 1.0;
        canvas.drawLine(Offset(x, halfH), Offset(x + unitWidth, halfH), hingeLinePaint);
        
        final Paint pinPaint = Paint()..color = Colors.white24..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x + 1.5, halfH), 0.8, pinPaint);
        canvas.drawCircle(Offset(x + unitWidth - 1.5, halfH), 0.8, pinPaint);
        return;
      }

      // 2. ACTIVE ANIMATION LOGIC:
      final int nextIndex = (currentIndex + 1) % alphabet.length;
      _drawHalf(canvas, Offset(x, 0), nextIndex, true, paint);
      _drawHalf(canvas, Offset(x, halfH), currentIndex, false, paint, shading: val > 0.5 ? (1.0 - val) * 0.35 : 0.0);

      final double angle = val * math.pi;
      canvas.save();
      canvas.translate(x + unitWidth / 2, halfH);
      
      final Matrix4 matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(-angle);
      canvas.transform(matrix.storage);
      
      final double flapShading = (0.5 - (val - 0.5).abs()) * 0.4;
      
      if (val > 0.5) {
        canvas.save();
        canvas.rotate(math.pi);
        _drawHalf(canvas, Offset(-unitWidth / 2, -halfH), nextIndex, false, paint, shading: flapShading);
        canvas.restore();
      } else {
        _drawHalf(canvas, Offset(-unitWidth / 2, -halfH), currentIndex, true, paint, shading: flapShading);
      }
      canvas.restore();

      final Paint hingeLinePaint = Paint()..color = Colors.black.withOpacity(0.6)..strokeWidth = 1.0;
      canvas.drawLine(Offset(x, halfH), Offset(x + unitWidth, halfH), hingeLinePaint);

      final Paint pinPaint = Paint()..color = Colors.white24..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x + 1.5, halfH), 0.8, pinPaint);
      canvas.drawCircle(Offset(x + unitWidth - 1.5, halfH), 0.8, pinPaint);
  }

  void _drawHalf(Canvas canvas, Offset offset, int charIndex, bool isTop, Paint paint, {double shading = 0.0}) {
    final src = _getCharRect(charIndex, isTop);
    
    if (shading > 0.01) {
        paint.colorFilter = ColorFilter.mode(Colors.black.withOpacity(shading), BlendMode.multiply);
    } else {
        paint.colorFilter = null;
    }

    canvas.drawImageRect(
        spriteSheet,
        src,
        Rect.fromLTWH(offset.dx, offset.dy, unitWidth, unitHeight / 2),
        paint
    );
  }

  @override
  bool shouldRepaint(covariant SplitFlapRowPainter oldDelegate) {
    // Repaint if the animation is moving OR if the underlying data has changed
    if (oldDelegate.animationValue != animationValue) return true;
    
    for (int i = 0; i < currentIndices.length; i++) {
        if (oldDelegate.currentIndices[i] != currentIndices[i]) return true;
        if (oldDelegate.remainingSteps[i] != remainingSteps[i]) return true;
    }
    
    return false;
  }
}
