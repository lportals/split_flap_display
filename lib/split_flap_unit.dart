import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplitFlapUnit extends StatefulWidget {
  final String targetChar;
  final double width;
  final double height;
  final Duration flipDuration;
  final Color backgroundColor;
  final Color flapColor;
  final Color textColor;
  final TextStyle? textStyle;
  final VoidCallback? onFlip;

  const SplitFlapUnit({
    super.key,
    required this.targetChar,
    this.width = 60,
    this.height = 90,
    this.flipDuration = const Duration(milliseconds: 75), // Optimized for 13.3Hz mechanical feel
    this.backgroundColor = const Color(0xFF1A1A1A),
    this.flapColor = const Color(0xFF252525),
    this.textColor = Colors.white,
    this.textStyle,
    this.onFlip,
  });

  @override
  State<SplitFlapUnit> createState() => _SplitFlapUnitState();
}

const String alphabet = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:-";

class _SplitFlapUnitState extends State<SplitFlapUnit> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _currentChar = ' ';
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = alphabet.indexOf(widget.targetChar);
    if (_currentIndex == -1) _currentIndex = 0;
    _currentChar = alphabet[_currentIndex];

    _controller = AnimationController(vsync: this, duration: widget.flipDuration);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _updateIndex();
        }
      });
  }

  void _updateIndex() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % alphabet.length;
      _currentChar = alphabet[_currentIndex];
      _controller.reset();
      if (_currentChar != widget.targetChar) {
        _controller.forward();
        if (widget.onFlip != null) widget.onFlip!();
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void didUpdateWidget(SplitFlapUnit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetChar != widget.targetChar) {
      if (!_controller.isAnimating) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final val = _animation.value;
          final angle = val * math.pi;
          final isPastHalfway = val > 0.5;
          final nextChar = alphabet[(_currentIndex + 1) % alphabet.length];
          
          // Shading: darker at the edge (90deg)
          final flapShading = (0.5 - (val - 0.5).abs()) * 0.4;
          final bottomBgShading = val > 0.5 ? (1.0 - val) * 0.35 : 0.0;

          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Static Top Half (Target Character)
                _buildHalf(isTop: true, char: nextChar),
                
                // 2. Static Bottom Half (Current Character) - Positioned at Bottom
                Positioned(
                  top: widget.height / 2,
                  child: _buildHalf(isTop: false, char: _currentChar, shading: bottomBgShading),
                ),

                // 3. The Rotating Flap
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..rotateX(-angle),
                  alignment: Alignment.center,
                  child: isPastHalfway
                      ? Transform(
                          transform: Matrix4.identity()..rotateX(math.pi),
                          alignment: Alignment.center,
                          child: _buildHalf(isTop: false, char: nextChar, shading: flapShading),
                        )
                      : _buildHalf(isTop: true, char: _currentChar, shading: flapShading),
                ),

                // 4. Center Hinge Line
                Center(
                  child: Container(
                    height: 1.5,
                    width: widget.width,
                    color: Colors.black.withOpacity(0.8),
                  ),
                ),
                
                // 5. Aesthetic Pins
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPin(),
                      _buildPin(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPin() {
    return Container(
      width: 2.5,
      height: 2.5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: const BoxDecoration(
        color: Colors.white12,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildHalf({required bool isTop, required String char, double shading = 0.0}) {
    // Advanced Performance: Instead of an Opacity layer, we blend the color directly.
    // This avoids creating off-screen buffers in Impeller.
    final Color blendedColor = Color.lerp(widget.flapColor, Colors.black, shading) ?? widget.flapColor;

    return ClipRect(
      child: Align(
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: blendedColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
          ),
          alignment: Alignment.center,
          child: Center(
            child: Text(
              char,
              style: (widget.textStyle ?? TextStyle(
                fontSize: widget.height * 0.75,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                height: 1.0,
                letterSpacing: -1.0,
              )).copyWith(color: widget.textColor),
            ),
          ),
        ),
      ),
    );
  }
}
