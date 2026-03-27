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
  SplitFlapRowPainter? _cachedPainter;

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
    final int colorVal = widget.textColor.value;
    final String key = "${widget.unitWidth.toInt()}-${widget.unitHeight.toInt()}-$colorVal";
    
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
      
      if (targetChar == ':' || targetChar == '.') {
        _currentIndices[i] = _targetIndices[i];
        _remainingSteps[i] = 0;
      } else {
        _remainingSteps[i] = (_targetIndices[i] - _currentIndices[i] + alphabet.length) % alphabet.length;
      }
    }
    
    if (!widget.silent) {
      int active = 0;
      for (var s in _remainingSteps) if (s > 0) active++;
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
      FlapSoundManager.instance.playClick();
    }

    if (anyRemaining) {
      _controller.reset();
      _controller.forward();
    } else {
      _controller.reset();
      if (mounted) setState(() {});
    }
    
    if (!widget.silent) {
      int active = 0;
      for (var s in _remainingSteps) if (s > 0) active++;
      FlapSoundManager.instance.updateRowActivity(hashCode, active);
    }
  }

  @override
  void didUpdateWidget(SplitFlapRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxLength != widget.maxLength) {
      _currentIndices = List.generate(widget.maxLength, (i) => (i < _currentIndices.length) ? _currentIndices[i] : 0);
      _targetIndices = List.generate(widget.maxLength, (i) => (i < _targetIndices.length) ? _targetIndices[i] : 0);
      _remainingSteps = List.generate(widget.maxLength, (i) => (i < _remainingSteps.length) ? _remainingSteps[i] : 0);
      _updateTargets(widget.text);
    } else if (oldWidget.text != widget.text) {
      _updateTargets(widget.text);
    }

    if (!_controller.isAnimating && _remainingSteps.any((s) => s > 0) && _isReady) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (!widget.silent) FlapSoundManager.instance.updateRowActivity(hashCode, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return SizedBox(
        height: widget.unitHeight, 
        width: (widget.unitWidth * widget.maxLength) + (widget.spacing * (widget.maxLength - 1))
      );
    }

    // Use a simple string key for the specific color + size combination
    final int colorVal = widget.textColor.value;
    final String key = "${widget.unitWidth.toInt()}-${widget.unitHeight.toInt()}-$colorVal";
    
    final sheet = _spriteSheets[key];
    if (sheet == null) return const SizedBox();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(
            (widget.unitWidth * widget.maxLength) + (widget.spacing * (widget.maxLength - 1)),
            widget.unitHeight,
          ),
          painter: SplitFlapRowPainter(
            val: _controller.value,
            currentIndices: List.from(_currentIndices),
            remainingSteps: List.from(_remainingSteps),
            unitWidth: widget.unitWidth,
            unitHeight: widget.unitHeight,
            spacing: widget.spacing,
            spriteSheet: sheet,
          ),
        );
      },
    );
  }
}

class SplitFlapRowPainter extends CustomPainter {
  final double val;
  final List<int> currentIndices;
  final List<int> remainingSteps;
  final double unitWidth;
  final double unitHeight;
  final double spacing;
  final ui.Image spriteSheet;

  // Static cache for Rects to avoid per-frame allocations
  static final Map<String, List<Rect>> _rectCache = {};
  
  static final Paint _mainPaint = Paint()..filterQuality = FilterQuality.low;
  static final Paint _shadingPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _hingePaint = Paint()..color = Colors.black..strokeWidth = 1.0;
  static final Paint _pinPaint = Paint()..color = const Color(0x33FFFFFF)..style = PaintingStyle.fill;

  SplitFlapRowPainter({
    required this.val,
    required this.currentIndices,
    required this.remainingSteps,
    required this.unitWidth,
    required this.unitHeight,
    required this.spacing,
    required this.spriteSheet,
  }) {
    final String key = "${unitWidth.toInt()}-${unitHeight.toInt()}";
    if (!_rectCache.containsKey(key)) {
      final List<Rect> rects = [];
      const int columns = 10;
      const double pr = 2.0; 
      // 80 entries for alphabet.length * 2
      for (int i = 0; i < 80; i++) {
        final int row = i ~/ columns;
        final int col = i % columns;
        rects.add(Rect.fromLTWH(
          col * unitWidth * pr,
          row * (unitHeight / 2) * pr,
          unitWidth * pr,
          (unitHeight / 2) * pr,
        ));
      }
      _rectCache[key] = rects;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final String rKey = "${unitWidth.toInt()}-${unitHeight.toInt()}";
    final rects = _rectCache[rKey];
    if (rects == null) return;

    double x = 0;
    final double halfH = unitHeight / 2;

    for (int i = 0; i < currentIndices.length; i++) {
      final int currIdx = currentIndices[i];
      final int nextIdx = (currIdx + 1) % alphabet.length;
      final bool active = remainingSteps[i] > 0;
      final double progress = active ? val : 0.0;

      if (progress < 0.001) {
        // Static State
        _drawHalf(canvas, x, 0, currIdx, true, rects, 0);
        _drawHalf(canvas, x, halfH, currIdx, false, rects, 0);
      } else {
        // Animation Logic
        final double shading = (0.5 - (progress - 0.5).abs()) * 0.4;
        
        // Base revealed background
        if (progress < 0.5) {
          _drawHalf(canvas, x, 0, nextIdx, true, rects, 0);       // revealed top
          _drawHalf(canvas, x, halfH, currIdx, false, rects, 0);  // static bottom
        } else {
          _drawHalf(canvas, x, 0, nextIdx, true, rects, 0);       // static top
          _drawHalf(canvas, x, halfH, nextIdx, false, rects, 0);  // revealed bottom
        }

        // Animated swinging flap
        canvas.save();
        canvas.translate(x + unitWidth / 2, halfH);
        
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(-progress * math.pi);
        canvas.transform(matrix.storage);

        if (progress < 0.5) {
          _drawHalf(canvas, -unitWidth / 2, -halfH, currIdx, true, rects, shading);
        } else {
          canvas.rotate(math.pi);
          _drawHalf(canvas, -unitWidth / 2, -halfH, nextIdx, false, rects, shading);
        }
        canvas.restore();
      }

      // Hardware detail lines
      canvas.drawLine(Offset(x, halfH), Offset(x + unitWidth, halfH), _hingePaint);
      canvas.drawCircle(Offset(x + 1.2, halfH), 0.7, _pinPaint);
      canvas.drawCircle(Offset(x + unitWidth - 1.2, halfH), 0.7, _pinPaint);

      x += (unitWidth + spacing);
    }
  }

  void _drawHalf(Canvas canvas, double dx, double dy, int idx, bool isTop, List<Rect> rects, double shade) {
    if (idx < 0 || idx >= alphabet.length) return;
    final src = rects[idx * 2 + (isTop ? 0 : 1)];
    final dst = Rect.fromLTWH(dx, dy, unitWidth, unitHeight / 2);
    canvas.drawImageRect(spriteSheet, src, dst, _mainPaint);
    if (shade > 0.01) {
      _shadingPaint.color = Colors.black.withOpacity(shade);
      canvas.drawRect(dst, _shadingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SplitFlapRowPainter oldDelegate) {
    return val != oldDelegate.val || 
           currentIndices != oldDelegate.currentIndices || 
           remainingSteps != oldDelegate.remainingSteps;
  }
}
