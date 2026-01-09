import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter 2D Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      initialRoute: '/',
      routes: {
        '/': (context) => const GameScreen(),
      },
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  // Oyun döngüsü için Ticker
  late Ticker _ticker;

  // Oyuncu özellikleri
  Offset _playerPos = Offset.zero;
  double _playerRadius = 20.0;
  double _moveSpeed = 5.0;
  double _rotation = 0.0; // Radyan cinsinden yön

  // Input durumları
  Offset _mousePos = Offset.zero;
  final Set<LogicalKeyboardKey> _pressedKeys = {};

  // Oyun nesneleri (Yemler)
  final List<Offset> _foods = [];
  final Random _rnd = Random();
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    // Oyun döngüsünü başlat
    _ticker = createTicker(_onTick)..start();
    
    // Başlangıçta rastgele yemler oluştur
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spawnFoods(10);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // Her karede (frame) çalışan fonksiyon
  void _onTick(Duration elapsed) {
    if (_screenSize == Size.zero) return;

    setState(() {
      _handleMovement();
      _handleCollision();
    });
  }

  // Hareket mantığı (Transform tabanlı, fizik yok)
  void _handleMovement() {
    // 1. Mouse'a dönme (Rotasyon hesaplama)
    // Oyuncudan mouse'a giden vektör
    double dx = _mousePos.dx - _playerPos.dx;
    double dy = _mousePos.dy - _playerPos.dy;
    _rotation = atan2(dy, dx);

    // 2. WASD ile Hareket
    Offset movement = Offset.zero;
    if (_pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      movement += const Offset(0, -1);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyS)) {
      movement += const Offset(0, 1);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      movement += const Offset(-1, 0);
    }
    if (_pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      movement += const Offset(1, 0);
    }

    // Eğer hareket varsa normalize et ve hızı ekle
    if (movement.distance > 0) {
      movement = movement / movement.distance * _moveSpeed;
      _playerPos += movement;
    }

    // Ekran sınırlarında tutma
    _playerPos = Offset(
      _playerPos.dx.clamp(_playerRadius, _screenSize.width - _playerRadius),
      _playerPos.dy.clamp(_playerRadius, _screenSize.height - _playerRadius),
    );
  }

  // Çarpışma ve Yeme mantığı
  void _handleCollision() {
    // Yemleri kontrol et
    _foods.removeWhere((foodPos) {
      double distance = (foodPos - _playerPos).distance;
      // Eğer mesafe yarıçaplar toplamından küçükse yemiş sayılır
      if (distance < _playerRadius + 5) { // +5 yemin yarıçapı
        _playerRadius += 2.0; // Boyutu büyüt
        return true; // Listeden sil
      }
      return false;
    });

    // Yemler biterse yenilerini ekle
    if (_foods.isEmpty) {
      _spawnFoods(5);
    }
  }

  // Rastgele yem oluşturma
  void _spawnFoods(int count) {
    if (_screenSize == Size.zero) return;
    for (int i = 0; i < count; i++) {
      _foods.add(Offset(
        _rnd.nextDouble() * _screenSize.width,
        _rnd.nextDouble() * _screenSize.height,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Ekran boyutunu güncelle
          if (_screenSize == Size.zero) {
            _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
            _playerPos = _screenSize.center(Offset.zero);
          }

          return Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                _pressedKeys.add(event.logicalKey);
              } else if (event is KeyUpEvent) {
                _pressedKeys.remove(event.logicalKey);
              }
              return KeyEventResult.handled;
            },
            child: MouseRegion(
              onHover: (event) {
                _mousePos = event.localPosition;
              },
              child: CustomPaint(
                painter: GamePainter(
                  playerPos: _playerPos,
                  playerRadius: _playerRadius,
                  rotation: _rotation,
                  foods: _foods,
                ),
                size: Size.infinite,
              ),
            ),
          );
        },
      ),
    );
  }
}

// Oyunu çizen sınıf
class GamePainter extends CustomPainter {
  final Offset playerPos;
  final double playerRadius;
  final double rotation;
  final List<Offset> foods;

  GamePainter({
    required this.playerPos,
    required this.playerRadius,
    required this.rotation,
    required this.foods,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint playerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final Paint foodPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    // Yemleri çiz
    for (var food in foods) {
      canvas.drawCircle(food, 8.0, foodPaint);
    }

    // Oyuncuyu çiz
    canvas.save();
    canvas.translate(playerPos.dx, playerPos.dy);
    canvas.rotate(rotation);
    
    // Gövde
    canvas.drawCircle(Offset.zero, playerRadius, playerPaint);
    
    // Yön göstergesi (Göz veya çizgi)
    final Paint directionPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset.zero, Offset(playerRadius, 0), directionPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
