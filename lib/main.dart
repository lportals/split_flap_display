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
  // Datos Estáticos para evitar duplicados en renderizado
  final List<DepartureData> _rows = [
    DepartureData('AB 1234', '09:15', 'NEW YORK', 'A01', 'BOARDING'),
    DepartureData('CD 5678', '09:30', 'PRAGUE', 'B04', 'ON TIME'),
    DepartureData('DE 0012', '09:55', 'LONDON', 'D20', 'ON TIME'),
    DepartureData('AB 0104', '10:05', 'DOHA', 'A03', 'DELAYED'),
    DepartureData('FP 0183', '10:15', 'CHICAGO', 'A06', 'ON TIME'),
    DepartureData('CA 1090', '10:20', 'MOSCOW', 'G01', 'ON TIME'),
    DepartureData('GX 1113', '10:30', 'PARIS', 'A04', 'ON TIME'),
    DepartureData('SE 0219', '10:55', 'BANGKOK', 'B04', 'ON TIME'),
    DepartureData('BA 7037', '11:00', 'LAS VEGAS', 'A10', 'ON TIME'),
    DepartureData('AB 0335', '11:05', 'BERLIN', 'E01', 'ON TIME'),
  ];

  final Color _yellow = const Color(0xFFFFD100); 
  String _time = "--:--";
  bool _shuffling = false;

  @override
  void initState() {
    super.initState();
    _startClock();
    _initBoard();
  }

  /// Preloads audio assets, then kicks off the first shuffle.
  /// The first shuffle will be visually active but silent (no user gesture
  /// yet). Audio unlocks transparently on the first tap anywhere.
  void _initBoard() async {
    await FlapSoundManager.instance.init();
    // Small delay so the user sees the board "wake up"
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) _shuffle();
  }

  void _startClock() {
    _updateTime();
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _updateTime();
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final newT = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    if (newT != _time) setState(() => _time = newT);
  }

  void _shuffle() async {
    if (_shuffling) return;
    setState(() => _shuffling = true);

    final tempRows = List<DepartureData>.from(_rows);
    tempRows.shuffle();
    for (int i = 0; i < _rows.length; i++) {
       await Future.delayed(const Duration(milliseconds: 150));
       if (!mounted) break;
       setState(() {
         _rows[i] = tempRows[i];
       });
    }
    setState(() => _shuffling = false);
  }

  @override
  Widget build(BuildContext context) {
    final double scW = MediaQuery.of(context).size.width;
    
    // BREAKPOINTS REFINADOS
    final bool isDesktop = scW > 1024;
    final bool isTablet = !isDesktop && scW > 640;
    final bool isMobile = scW <= 640;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Color(0xFF0A0A0A), Color(0xFF000000)],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildMainBoard(isDesktop, isTablet, isMobile),
                ),
              ),
              const SizedBox(height: 50),
              _buildButton(),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildMainBoard(bool isDesktop, bool isTablet, bool isMobile) {
    // Exact dimensions calculation helper
    double getColW(int chars, double uW, double spa) => (chars * uW) + ((chars - 1) * spa);

    // Dynamic dimensions based on Device
    final double h = isDesktop ? 38 : (isTablet ? 32 : 28);
    final double w = isDesktop ? 20 : (isTablet ? 18 : 16);
    const double sp = 3.0;

    // Fixed character lengths per column
    const int lenF = 7; // FLIGHT
    const int lenT = 5; // TIME
    final int lenD = isDesktop ? 12 : 15; // Set to 15 for both mobile/tablet for consistency
    const int lenG = 3; // GATE
    const int lenS = 8; // STATUS

    // Exact Widths for Columns
    final double wF = isDesktop ? getColW(lenF, w, sp) : 0;
    final double wT = getColW(lenT, w, sp);
    final double wD = getColW(lenD, w, sp);
    final double wG = isDesktop ? getColW(lenG, w, sp) : 0;
    final double wS = isMobile ? 0 : getColW(lenS, w, sp);
    
    final double gap = isDesktop ? 30 : (isTablet ? 20 : 12);

    // Calculate total layout width for centering
    double totalW = wT + gap + wD;
    if (isTablet) totalW = wT + gap + wD + gap + wS;
    if (isDesktop) totalW = wF + gap + wT + gap + wD + gap + wG + gap + wS;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 44 : (isTablet ? 28 : 20)),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.95), blurRadius: 60, spreadRadius: 10),
          BoxShadow(color: _yellow.withOpacity(0.015), blurRadius: 120, spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile, totalW, wT, h, w, sp),
          const SizedBox(height: 40),
          _buildColumns(isDesktop, isTablet, isMobile, wF, wT, wD, wG, wS, gap),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.white.withOpacity(0.04), height: 1, thickness: 1),
          ),
          // Rows Render
          ..._rows.asMap().entries.map((entry) {
            final int index = entry.key;
            final DepartureData rowData = entry.value;
            return Padding(
              key: ValueKey('board_row_${rowData.flight}_$index'),
              padding: const EdgeInsets.symmetric(vertical: 5.5),
              child: _buildRow(rowData, isDesktop, isTablet, isMobile, wF, wT, wD, wG, wS, gap, h, w, sp, lenF, lenT, lenD, lenG, lenS),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, double width, double wT, double h, double w, double sp) {
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
                  color: _yellow,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _yellow.withOpacity(0.4), blurRadius: 20, spreadRadius: -5)]
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
                      color: _yellow.withOpacity(0.6), 
                      fontSize: isMobile ? 7 : 9, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2
                    )
                  ),
                ],
              ),
            ],
          ),
          if (!isMobile) Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("LOCAL TIME", style: TextStyle(color: _yellow.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              // Time at the top matches exactly the width of the Time column for symmetry
              SizedBox(
                width: wT,
                child: SplitFlapRow(
                  key: const ValueKey('header_clock_flap'),
                  text: _time, 
                  maxLength: 5, 
                  unitWidth: w, 
                  unitHeight: h, 
                  spacing: sp, 
                  textColor: _yellow, 
                  silent: true
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColumns(bool isD, bool isT, bool isM, double wF, double wT, double wD, double wG, double wS, double gap) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isD) ...[_title("FLIGHT", wF), SizedBox(width: gap)],
        _title("TIME", wT),
        SizedBox(width: gap),
        _title("DESTINATION", wD),
        if (isD) ...[SizedBox(width: gap), _title("GATE", wG)],
        if (!isM) ...[SizedBox(width: gap), _title("STATUS", wS)],
      ],
    );
  }

  Widget _title(String txt, double w) => SizedBox(
    width: w, 
    child: Text(txt, 
      style: TextStyle(
        color: Colors.white.withOpacity(0.12), 
        fontSize: 10, 
        fontWeight: FontWeight.w800, 
        letterSpacing: 2.0
      )
    )
  );

  Widget _buildRow(DepartureData d, bool isD, bool isT, bool isM, double wF, double wT, double wD, double wG, double wS, double gap, double h, double w, double sp, int lenF, int lenT, int lenD, int lenG, int lenS) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isD) ...[_flap(lenF, d.flight, h, w, sp, wF, Colors.white), SizedBox(width: gap)],
        _flap(lenT, d.time, h, w, sp, wT, _yellow),
        SizedBox(width: gap),
        _flap(lenD, d.destination, h, w, sp, wD, Colors.white),
        if (isD) ...[SizedBox(width: gap), _flap(lenG, d.gate, h, w, sp, wG, _yellow)],
        if (!isM) ...[SizedBox(width: gap), _flap(lenS, d.status, h, w, sp, wS, Colors.white)],
      ],
    );
  }

  Widget _flap(int max, String val, double h, double w, double sp, double containerW, Color col) {
     if (containerW <= 0) return const SizedBox.shrink();
     return SizedBox(
       width: containerW,
       child: SplitFlapRow(text: val, maxLength: max, unitWidth: w, unitHeight: h, spacing: sp, textColor: col),
     );
  }

  Widget _buildButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _yellow.withOpacity(0.15), blurRadius: 40, spreadRadius: -10)]
      ),
      child: ElevatedButton.icon(
        onPressed: _shuffling ? null : _shuffle,
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

class DepartureData {
  String flight; String time; String destination; String gate; String status;
  DepartureData(this.flight, this.time, this.destination, this.gate, this.status);
}
