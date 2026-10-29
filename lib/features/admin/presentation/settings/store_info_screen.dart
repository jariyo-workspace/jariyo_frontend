import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../../store/domain/store_entities.dart';
import '../../domain/admin_entities.dart';
import '../../domain/admin_repositories.dart';
import '../../domain/admin_settings_usecases.dart';
import '../admin_common.dart';

class StoreInfoViewModel extends LoadableViewModel<StoreDetail> {
  StoreInfoViewModel(this.storeId, StoreSettingsRepository repository, this._bus)
    : _get = GetManagedStore(repository),
      _update = UpdateStoreInfo(repository);

  final String storeId;
  final RefreshBus _bus;
  final GetManagedStore _get;
  final UpdateStoreInfo _update;

  @override
  Future<StoreDetail> fetch() => _get(storeId);

  Future<bool> save(StoreInfoInput input) => runAction('save', () async {
    await _update(storeId, input);
    _bus.emit({RefreshTopic.storeDetail, RefreshTopic.adminSettings});
    AppMessenger.show('매장 정보를 저장했어요.');
    await refresh();
  });
}

/// 매장 정보 (매장명, 소개, 전화번호, 주소)
class StoreInfoScreen extends StatelessWidget {
  const StoreInfoScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<StoreInfoViewModel>(
      create: () => StoreInfoViewModel(ctx.storeId, GetIt.I<StoreSettingsRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('매장 정보')),
        body: LoadableBody<StoreDetail>(
          vm: vm,
          pullToRefresh: false,
          builder: (context, store) => _StoreForm(key: ValueKey(store), store: store, vm: vm),
        ),
      ),
    );
  }
}

class _StoreForm extends StatefulWidget {
  const _StoreForm({super.key, required this.store, required this.vm});

  final StoreDetail store;
  final StoreInfoViewModel vm;

  @override
  State<_StoreForm> createState() => _StoreFormState();
}

class _StoreFormState extends State<_StoreForm> {
  late final _name = TextEditingController(text: widget.store.name);
  late final _description = TextEditingController(text: widget.store.description);
  late final _phone = TextEditingController(text: widget.store.phoneNumber);
  late final _address = TextEditingController(text: widget.store.address);

  @override
  void dispose() {
    for (final c in [_name, _description, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _phone.text.trim().isNotEmpty && _address.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: '매장명'), maxLength: 200, onChanged: (_) => setState(() {})),
        TextField(controller: _description, decoration: const InputDecoration(labelText: '매장 소개 · 공지'), maxLength: 1000, maxLines: 4),
        TextField(
          controller: _phone,
          decoration: const InputDecoration(labelText: '전화번호'),
          keyboardType: TextInputType.phone,
          maxLength: 32,
          onChanged: (_) => setState(() {}),
        ),
        TextField(controller: _address, decoration: const InputDecoration(labelText: '주소'), maxLength: 500, onChanged: (_) => setState(() {})),
        InfoRow(label: '시간대', value: '${widget.store.timezone} (변경 불가)'),
        const SizedBox(height: 16),
        AppButton(
          label: '저장',
          loading: widget.vm.isBusy('save'),
          onPressed: _valid
              ? () => widget.vm.save(
                  StoreInfoInput(
                    name: _name.text.trim(),
                    description: _description.text.trim(),
                    phoneNumber: _phone.text.trim(),
                    address: _address.text.trim(),
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
