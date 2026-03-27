import 'dart:async';
import 'package:flutter/material.dart';
import 'split_flap_row.dart';
import 'flap_sound_manager.dart';

void main() {
  runApp(const SplitFlapApp());
}

class SplitFlapApp extends StatelessWidget {
  const SplitFlapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020202),
        canvasColor: Colors.black,
      ),
      home: const DepartureBoardScreen(),
    );
  }
}

class DepartureBoardScreen extends StatefulWidget {
  const DepartureBoardScreen({super.key});

  @override
  State<DepartureBoardScreen> createState() => _DepartureBoardScreenState();
}

class _DepartureBoardScreenState extends State<DepartureBoardScreen> {
   // Use ValueNotifiers to update each row independently without full-screen rebuilds
   final List<ValueNotifier<DepartureData>> _rowNotifiers = [
     ValueNotifier(DepartureData('AB 1234', '09:15', 'NEW YORK', 'A01', 'BOARDING')),
     ValueNotifier(DepartureData('CD 5678', '09:30', 'PRAGUE', 'B04', 'ON TIME')),
     ValueNotifier(DepartureData('DE 0012', '09:55', 'LONDON', 'D20', 'ON TIME')),
     ValueNotifier(DepartureData('AB 0104', '10:05', 'DOHA', 'A03', 'DELAYED')),
     ValueNotifier(DepartureData('FP 0183', '10:15', 'CHICAGO', 'A06', 'ON TIME')),
     ValueNotifier(DepartureData('CA 1090', '10:20', 'MOSCOW', 'G01', 'ON TIME')),
     ValueNotifier(DepartureData('GX 1113', '10:30', 'PARIS', 'A04', 'ON TIME')),
     ValueNotifier(DepartureData('SE 0219', '10:55', 'BANGKOK', 'B04', 'ON TIME')),
     ValueNotifier(DepartureData('BA 7037', '11:00', 'LAS VEGAS', 'A10', 'ON TIME')),
     ValueNotifier(DepartureData('AB 0335', '11:05', 'BERLIN', 'E01', 'ON TIME')),
   ];
 
   final Color _yellow = const Color(0xFFFFD100); 
   bool _shuffling = false;
 
   @override
   void initState() {
     super.initState();
     _initBoard();
   }
 
   void _initBoard() async {
     await FlapSoundManager.instance.init();
     await Future.delayed(const Duration(milliseconds: 600));
     if (mounted) _shuffle();
   }
 
   void _shuffle() async {
     if (_shuffling) return;
     setState(() => _shuffling = true);
 
     // Target data for the shuffle
     final tempRows = _rowNotifiers.map((n) => n.value).toList()..shuffle();
     
     for (int i = 0; i < _rowNotifiers.length; i++) {
        // Reduced delay since it's zero parent rebuild overhead now
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) break;
        // Notifying only this row: NO parent build budget is spent
        _rowNotifiers[i].value = tempRows[i]; 
     }
     
     setState(() => _shuffling = false);
   }

  void _onShufflePressed() {
     FlapSoundManager.instance.playClick();
     _shuffle();
  }

   @override
   Widget build(BuildContext context) {
     final double scW = MediaQuery.of(context).size.width;
     final bool isDesktop = scW > 1024;
     final bool isTablet = !isDesktop && scW > 640;
     final bool isMobile = scW <= 640;

     return Scaffold(
       backgroundColor: const Color(0xFF020202),
       body: Stack(
         children: [
           // Static Background
           const Positioned.fill(
             child: RepaintBoundary(
               child: _StaticBackground(),
             ),
           ),
           // Scrollable Content
           Positioned.fill(
             child: SingleChildScrollView(
               physics: const BouncingScrollPhysics(),
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Center(
                     child: RepaintBoundary(
                       key: const ValueKey('main_board_repaint'),
                       child: _buildMainBoard(isDesktop, isTablet, isMobile),
                     ),
                   ),
                   const SizedBox(height: 50),
                   _buildButton(),
                 ],
               ),
             ),
           ),
         ],
       ),
     );
   }

   Widget _buildMainBoard(bool isDesktop, bool isTablet, bool isMobile) {
     double getColW(int chars, double uW, double spa) => (chars * uW) + ((chars - 1) * spa);

     final double h = isDesktop ? 38 : (isTablet ? 32 : 28);
     final double w = isDesktop ? 20 : (isTablet ? 18 : 16);
     const double sp = 3.0;

     const int lenF = 7;
     const int lenT = 5;
     final int lenD = isDesktop ? 12 : 15;
     const int lenG = 3;
     const int lenS = 8;

     final double wF = isDesktop ? getColW(lenF, w, sp) : 0;
     final double wT = getColW(lenT, w, sp);
     final double wD = getColW(lenD, w, sp);
     final double wG = isDesktop ? getColW(lenG, w, sp) : 0;
     final double wS = isMobile ? 0 : getColW(lenS, w, sp);
     
     final double gap = isDesktop ? 30 : (isTablet ? 20 : 12);

     double totalW = wT + gap + wD;
     if (isTablet) totalW = wT + gap + wD + gap + wS;
     if (isDesktop) totalW = wF + gap + wT + gap + wD + gap + wG + gap + wS;

     return Container(
       padding: EdgeInsets.all(isDesktop ? 44 : (isTablet ? 28 : 20)),
       decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(isMobile ? 18 : 28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.95), 
              blurRadius: isMobile ? 20 : 60, 
              spreadRadius: isMobile ? 2 : 10
            ),
          ],
       ),
       child: FittedBox(
         fit: BoxFit.scaleDown,
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              _BoardHeader(isMobile: isMobile, width: totalW, wT: wT, h: h, w: w, sp: sp, yellow: _yellow),
              const SizedBox(height: 40),
              RepaintBoundary(
                child: _buildColumnTitles(isDesktop, isTablet, isMobile, wF, wT, wD, wG, wS, gap),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: Colors.white.withValues(alpha: 0.04), height: 1, thickness: 1),
              ),
              _BoardGrid(
                rows: _rowNotifiers,
               isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile,
               wF: wF, wT: wT, wD: wD, wG: wG, wS: wS,
               gap: gap, h: h, w: w, sp: sp,
               lenF: lenF, lenT: lenT, lenD: lenD, lenG: lenG, lenS: lenS,
               yellow: _yellow,
             ),
           ],
         ),
       ),
     );
   }

   Widget _buildColumnTitles(bool isD, bool isT, bool isM, double wF, double wT, double wD, double wG, double wS, double gap) {
     Widget title(String txt, double w) => SizedBox(
        width: w, 
        child: Text(txt, 
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.12), 
            fontSize: 10, 
            fontWeight: FontWeight.w800, 
            letterSpacing: 2.0
          )
        )
      );

     return Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         if (isD) ...[title("FLIGHT", wF), SizedBox(width: gap)],
         title("TIME", wT),
         SizedBox(width: gap),
         title("DESTINATION", wD),
         if (isD) ...[SizedBox(width: gap), title("GATE", wG)],
         if (!isM) ...[SizedBox(width: gap), title("STATUS", wS)],
       ],
     );
   }

   Widget _buildButton() {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: _yellow.withOpacity(0.12), blurRadius: 40, spreadRadius: -10)]
        ),
       child: ElevatedButton.icon(
         onPressed: _shuffling ? null : _onShufflePressed,
         icon: Icon(_shuffling ? Icons.more_horiz : Icons.sync, color: Colors.black, size: 22),
          label: Text(_shuffling ? "UPDATING BOARD..." : "RELOAD FLIGHTS", 
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _yellow, 
            disabledBackgroundColor: _yellow.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
           elevation: 0,
         ),
       ),
     );
   }
}

class _StaticBackground extends StatelessWidget {
  const _StaticBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [Color(0xFF0A0A0A), Color(0xFF000000)],
        ),
      ),
    );
  }
}

class _BoardHeader extends StatelessWidget {
  final bool isMobile;
  final double width;
  final double wT;
  final double h;
  final double w;
  final double sp;
  final Color yellow;

  const _BoardHeader({
    required this.isMobile,
    required this.width,
    required this.wT,
    required this.h,
    required this.w,
    required this.sp,
    required this.yellow,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: yellow,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: yellow.withOpacity(0.4), blurRadius: 20, spreadRadius: -5)]
                ),
                child: Icon(Icons.flight_takeoff, color: Colors.black, size: isMobile ? 18 : 28),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("FLIGHT DEPARTURES", 
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: isMobile ? 16 : 28, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: -0.6
                    )
                  ),
                  Text("REAL-TIME GLOBAL STATUS", 
                    style: TextStyle(
                      color: yellow.withOpacity(0.6), 
                      fontSize: isMobile ? 7 : 9, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2
                    )
                  ),
                ],
              ),
            ],
          ),
          if (!isMobile) _ClockWidget(wT: wT, w: w, h: h, sp: sp, yellow: yellow),
        ],
      ),
    );
  }
}

class _ClockWidget extends StatefulWidget {
  final double wT;
  final double w;
  final double h;
  final double sp;
  final Color yellow;

  const _ClockWidget({required this.wT, required this.w, required this.h, required this.sp, required this.yellow});

  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  String _time = "--:--";
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final newT = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    if (newT != _time) {
      if (mounted) setState(() => _time = newT);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
       children: [
         Text("LOCAL TIME", style: TextStyle(color: widget.yellow.withValues(alpha: 0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
         const SizedBox(height: 6),
        SizedBox(
          width: widget.wT,
          child: RepaintBoundary(
            key: const ValueKey('clock_repaint_boundary'),
            child: SplitFlapRow(
              key: const ValueKey('header_clock_flap'),
              text: _time, 
              maxLength: 5, 
              unitWidth: widget.w, 
              unitHeight: widget.h, 
              spacing: widget.sp, 
              textColor: widget.yellow, 
              silent: true
            ),
          ),
        ),
      ],
    );
  }
 }
 
 class _BoardGrid extends StatelessWidget {
   final List<ValueNotifier<DepartureData>> rows;
   final bool isDesktop;
  final bool isTablet;
  final bool isMobile;
  final double wF, wT, wD, wG, wS, gap, h, w, sp;
  final int lenF, lenT, lenD, lenG, lenS;
  final Color yellow;

  const _BoardGrid({
    required this.rows,
    required this.isDesktop, required this.isTablet, required this.isMobile,
    required this.wF, required this.wT, required this.wD, required this.wG, required this.wS,
    required this.gap, required this.h, required this.w, required this.sp,
    required this.lenF, required this.lenT, required this.lenD, required this.lenG, required this.lenS,
    required this.yellow,
  });

  @override
  Widget build(BuildContext context) {
     return Column(
       mainAxisSize: MainAxisSize.min,
       crossAxisAlignment: CrossAxisAlignment.start,
       children: List.generate(rows.length, (index) {
         return ValueListenableBuilder<DepartureData>(
           valueListenable: rows[index],
           builder: (context, data, _) {
             return RepaintBoundary(
               key: ValueKey('board_row_repaint_$index'),
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 5.5),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     if (isDesktop) ...[_flap(lenF, data.flight, wF, Colors.white, 'flight_$index'), SizedBox(width: gap)],
                     _flap(lenT, data.time, wT, yellow, 'time_$index'),
                     SizedBox(width: gap),
                     _flap(lenD, data.destination, wD, Colors.white, 'dest_$index'),
                     if (isDesktop) ...[SizedBox(width: gap), _flap(lenG, data.gate, wG, yellow, 'gate_$index')],
                     if (!isMobile) ...[SizedBox(width: gap), _flap(lenS, data.status, wS, Colors.white, 'status_$index')],
                   ],
                 ),
               ),
             );
           },
         );
       }),
     );
  }

  Widget _flap(int max, String val, double containerW, Color col, String keyPrefix) {
     if (containerW <= 0) return const SizedBox.shrink();
     return SizedBox(
       width: containerW,
       child: SplitFlapRow(
         key: ValueKey('flap_${keyPrefix}_$max'),
         text: val, 
         maxLength: max, 
         unitWidth: w, 
         unitHeight: h, 
         spacing: sp, 
         textColor: col
       ),
     );
  }
}

class DepartureData {
  String flight; String time; String destination; String gate; String status;
  DepartureData(this.flight, this.time, this.destination, this.gate, this.status);
}

