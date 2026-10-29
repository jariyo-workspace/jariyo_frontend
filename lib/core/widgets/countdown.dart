import 'dart:async';

import 'package:flutter/material.dart';

import '../utils/date_time_format.dart';

/// 서버가 내려준 만료 시각까지 남은 시간을 1초마다 다시 그린다.
///
/// 클라이언트 시계만 믿지 않도록, 만료되면 [onExpired]에서 서버 상태를 다시 조회한다.
class CountdownBuilder extends StatefulWidget {
  const CountdownBuilder({super.key, required this.expiresAt, required this.builder, this.onExpired});

  final DateTime expiresAt;
  final Widget Function(BuildContext context, Duration remaining) builder;
  final VoidCallback? onExpired;

  @override
  State<CountdownBuilder> createState() => _CountdownBuilderState();
}

class _CountdownBuilderState extends State<CountdownBuilder> {
  Timer? _timer;
  bool _notified = false;

  Duration get _remaining => widget.expiresAt.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(CountdownBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _notified = false;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_notified && _remaining.inSeconds <= 0) {
      _notified = true;
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}

/// `02:41 안에 선택해 주세요` 형태의 문구. 숫자와 문장을 함께 제공한다.
class CountdownText extends StatelessWidget {
  const CountdownText({super.key, required this.expiresAt, this.suffix = '', this.style, this.onExpired});

  final DateTime expiresAt;
  final String suffix;
  final TextStyle? style;
  final VoidCallback? onExpired;

  @override
  Widget build(BuildContext context) {
    return CountdownBuilder(
      expiresAt: expiresAt,
      onExpired: onExpired,
      builder: (context, remaining) => Semantics(
        label: describeRemaining(remaining),
        child: ExcludeSemantics(child: Text('${formatCountdown(remaining)}$suffix', style: style)),
      ),
    );
  }
}
