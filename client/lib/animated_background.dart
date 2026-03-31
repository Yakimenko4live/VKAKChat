import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final int numberOfPoints;
  final double connectionDistance;
  final Duration animationDuration;

  const AnimatedBackground({
    Key? key,
    this.numberOfPoints = 35,
    this.connectionDistance = 180.0,
    this.animationDuration = const Duration(milliseconds: 50),
  }) : super(key: key);

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late List<_Point> points;
  late AnimationController _controller;
  final Random _random = Random();
  late Size _size;

  @override
  void initState() {
    super.initState();
    _initPoints();
    _controller =
        AnimationController(vsync: this, duration: widget.animationDuration)
          ..addListener(() {
            _updatePoints();
            setState(() {});
          });
    _controller.repeat();
  }

  void _initPoints() {
    points = List.generate(widget.numberOfPoints, (index) {
      return _Point(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        vx: (_random.nextDouble() - 0.5) * 0.0015, // Еще медленнее
        vy: (_random.nextDouble() - 0.5) * 0.0015,
      );
    });
  }

  void _updatePoints() {
    for (var point in points) {
      point.x += point.vx;
      point.y += point.vy;

      if (point.x <= 0 || point.x >= 1) {
        point.vx = -point.vx;
        point.x = point.x.clamp(0.0, 1.0);
      }
      if (point.y <= 0 || point.y >= 1) {
        point.vy = -point.vy;
        point.y = point.y.clamp(0.0, 1.0);
      }
    }
  }

  List<List<int>> _findConnections(Size size) {
    List<List<int>> connections = [];
    double maxDistance = widget.connectionDistance;

    for (int i = 0; i < points.length; i++) {
      List<_DistanceIndex> distances = [];

      for (int j = 0; j < points.length; j++) {
        if (i == j) continue;

        double dx = (points[i].x - points[j].x) * size.width;
        double dy = (points[i].y - points[j].y) * size.height;
        double distance = sqrt(dx * dx + dy * dy);

        // Только точки на расстоянии меньше maxDistance
        if (distance < maxDistance) {
          distances.add(_DistanceIndex(distance: distance, index: j));
        }
      }

      distances.sort((a, b) => a.distance.compareTo(b.distance));

      // Соединяем с 2 ближайшими точками в пределах дистанции
      int connectionsCount = distances.length.clamp(2, 2);
      for (int k = 0; k < connectionsCount && k < distances.length; k++) {
        connections.add([i, distances[k].index]);
      }
    }

    // Убираем дубликаты
    Set<String> uniqueConnections = {};
    List<List<int>> uniqueList = [];

    for (var conn in connections) {
      String key = '${min(conn[0], conn[1])}-${max(conn[0], conn[1])}';
      if (!uniqueConnections.contains(key)) {
        uniqueConnections.add(key);
        uniqueList.add(conn);
      }
    }

    return uniqueList;
  }

  @override
  Widget build(BuildContext context) {
    _size = MediaQuery.of(context).size;
    final connections = _findConnections(_size);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFF2A341A), // Темный хаки, приглушенный
            Color(0xFF3D4A28), // Средний хаки
            Color(0xFF4F5E34), // Светлый хаки, не яркий
            Color(0xFF354223), // Оливковый
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _PointConnectionPainter(
          points: points,
          connections: connections,
          size: _size,
        ),
        size: _size,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _Point {
  double x;
  double y;
  double vx;
  double vy;

  _Point({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });
}

class _DistanceIndex {
  final double distance;
  final int index;

  _DistanceIndex({required this.distance, required this.index});
}

class _PointConnectionPainter extends CustomPainter {
  final List<_Point> points;
  final List<List<int>> connections;
  final Size size;

  _PointConnectionPainter({
    required this.points,
    required this.connections,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Сначала рисуем свечение для линий
    for (var connection in connections) {
      final point1 = points[connection[0]];
      final point2 = points[connection[1]];

      // Свечение линии (более широкое и прозрачное)
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.08)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawLine(
        Offset(point1.x * size.width, point1.y * size.height),
        Offset(point2.x * size.width, point2.y * size.height),
        glowPaint,
      );
    }

    // Рисуем основные линии (тонкие и приглушенные)
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var connection in connections) {
      final point1 = points[connection[0]];
      final point2 = points[connection[1]];

      canvas.drawLine(
        Offset(point1.x * size.width, point1.y * size.height),
        Offset(point2.x * size.width, point2.y * size.height),
        linePaint,
      );
    }

    // Рисуем свечение для точек
    for (var point in points) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        12.0,
        glowPaint,
      );
    }

    // Рисуем основные точки (приглушенные)
    final pointPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        2.5,
        pointPaint,
      );
    }

    // Внутреннее ядро точек (чуть ярче)
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(
        Offset(point.x * size.width, point.y * size.height),
        1.2,
        corePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PointConnectionPainter oldDelegate) {
    return true;
  }
}
