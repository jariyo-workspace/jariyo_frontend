import 'package:flutter/material.dart';

import '../presentation/view_model.dart';
import 'common_widgets.dart';

/// 화면 수명에 맞춰 ViewModel을 만들고 정리한다.
class ViewModelScope<T extends ChangeNotifier> extends StatefulWidget {
  const ViewModelScope({super.key, required this.create, required this.builder, this.onReady});

  final T Function() create;
  final Widget Function(BuildContext context, T vm) builder;
  final void Function(T vm)? onReady;

  @override
  State<ViewModelScope<T>> createState() => _ViewModelScopeState<T>();
}

class _ViewModelScopeState<T extends ChangeNotifier> extends State<ViewModelScope<T>> {
  late final T _vm = widget.create();

  @override
  void initState() {
    super.initState();
    widget.onReady?.call(_vm);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: _vm, builder: (context, _) => widget.builder(context, _vm));
}

/// [LoadableViewModel]의 전체 화면 로딩·오류·데이터 상태를 그린다.
class LoadableBody<T> extends StatelessWidget {
  const LoadableBody({
    super.key,
    required this.vm,
    required this.builder,
    this.loadingMessage,
    this.staleMessage = '정보를 새로 불러오지 못했어요.',
    this.pullToRefresh = true,
  });

  final LoadableViewModel<T> vm;
  final Widget Function(BuildContext context, T data) builder;
  final String? loadingMessage;
  final String staleMessage;
  final bool pullToRefresh;

  @override
  Widget build(BuildContext context) {
    final data = vm.data;
    if (data == null) {
      if (vm.error != null) return ErrorView(failure: vm.error!, onRetry: vm.load);
      return LoadingView(message: loadingMessage);
    }
    Widget body = builder(context, data);
    if (pullToRefresh) body = RefreshIndicator(onRefresh: vm.refresh, child: body);
    if (vm.refreshError == null) return body;
    return Column(
      children: [
        StaleBanner(message: staleMessage, onRetry: vm.refresh),
        Expanded(child: body),
      ],
    );
  }
}
