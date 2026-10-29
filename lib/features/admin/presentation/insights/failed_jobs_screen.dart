import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/domain/paged.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/network/idempotency.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../../core/realtime/refresh_bus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_time_format.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/view_model_scope.dart';
import '../../domain/admin_entities.dart';
import '../../domain/admin_insights_usecases.dart';
import '../../domain/admin_repositories.dart';
import '../admin_common.dart';
import '../admin_reservation_detail_screen.dart';

class FailedJobsViewModel extends LoadableViewModel<Paged<FailedJob>> {
  FailedJobsViewModel(this.storeId, AdminInsightsRepository repository, RefreshBus bus)
    : _list = GetFailedJobs(repository),
      _detail = GetFailedJob(repository),
      _resolve = ResolveFailedJob(repository) {
    listenTopics(bus, {RefreshTopic.adminFailedJobs}, refresh);
  }

  final String storeId;
  final GetFailedJobs _list;
  final GetFailedJob _detail;
  final ResolveFailedJob _resolve;
  final _retryKeys = <String, IdempotencyKeyHolder>{};
  FailedJobStatus? status = FailedJobStatus.failed;

  @override
  Future<Paged<FailedJob>> fetch() => _list(storeId, status: status);

  void setStatus(FailedJobStatus? value) {
    status = value;
    load();
  }

  Future<FailedJob> detail(FailedJob job) async {
    try {
      return await _detail(storeId, job.id);
    } on AppFailure {
      return job;
    }
  }

  Future<bool> retry(String jobId) {
    final holder = _retryKeys.putIfAbsent(jobId, IdempotencyKeyHolder.new);
    final key = holder.keyFor(jobId);
    return runAction(
      'retry:$jobId',
      () async {
        await _resolve.retry(storeId, jobId, idempotencyKey: key);
        holder.settle();
        AppMessenger.show('다시 처리하도록 요청했어요.');
        await refresh();
      },
      onFailure: (failure) {
        if (failure.kind != FailureKind.unknownOutcome) holder.settle();
        refresh();
        return false;
      },
    );
  }

  Future<bool> ignore(String jobId, String reason) => runAction('ignore:$jobId', () async {
    await _resolve.ignore(storeId, jobId, reason: reason);
    AppMessenger.show('무시 처리했어요.');
    await refresh();
  });
}

/// A-17 처리 실패 관리. 기술적인 오류 원문은 접어서 보여준다.
class FailedJobsScreen extends StatelessWidget {
  const FailedJobsScreen({super.key, required this.ctx});

  final OperatorContext ctx;

  Future<void> _showDetail(BuildContext context, FailedJobsViewModel vm, FailedJob job) async {
    final detail = await vm.detail(job);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.typeLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              InfoRow(label: '현재 상태', value: detail.status.label),
              InfoRow(label: '관련 대상', value: '${targetTypeLabel(detail.referenceType)} ${detail.referenceId ?? ''}'),
              if (detail.failedAt != null) InfoRow(label: '실패 시각', value: formatDateTime(detail.failedAt!)),
              InfoRow(label: '재시도 횟수', value: '${detail.attemptCount}회'),
              InfoRow(label: '오류 설명', value: detail.errorMessage ?? '-'),
              if (detail.ignoredReason != null) InfoRow(label: '무시 사유', value: detail.ignoredReason!),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('기술 정보'),
                children: [
                  SelectableText(
                    'code: ${detail.errorCode ?? '-'}\npayload: ${detail.payloadJson ?? '-'}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelScope<FailedJobsViewModel>(
      create: () => FailedJobsViewModel(ctx.storeId, GetIt.I<AdminInsightsRepository>(), GetIt.I<RefreshBus>()),
      onReady: (vm) => vm.load(),
      builder: (context, vm) => Scaffold(
        appBar: AppBar(title: const Text('처리 실패 관리')),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  for (final s in [null, ...FailedJobStatus.values]) ...[
                    ChoiceChip(label: Text(s?.label ?? '전체'), selected: vm.status == s, onSelected: (_) => vm.setStatus(s)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Expanded(
              child: LoadableBody<Paged<FailedJob>>(
                vm: vm,
                builder: (context, page) {
                  if (page.items.isEmpty) {
                    return ListView(
                      children: const [SizedBox(height: 80), EmptyView(icon: Icons.verified_outlined, title: '처리가 필요한 실패 작업이 없어요.')],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final job = page.items[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(job.typeLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                                  StatusBadge(label: job.status.label, tone: job.status.tone),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  '${targetTypeLabel(job.referenceType)} 관련',
                                  if (job.failedAt != null) formatDateTime(job.failedAt!),
                                  '재시도 ${job.attemptCount}회',
                                ].join(' · '),
                                style: const TextStyle(color: AppColors.lightText),
                              ),
                              if (job.errorMessage != null) ...[
                                const SizedBox(height: 4),
                                Text(job.errorMessage!),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (job.canRetry)
                                    AppButton(
                                      label: '다시 처리',
                                      expand: false,
                                      loading: vm.isBusy('retry:${job.id}'),
                                      onPressed: () => vm.retry(job.id),
                                    ),
                                  AppButton(
                                    label: '상세 보기',
                                    expand: false,
                                    variant: AppButtonVariant.secondary,
                                    onPressed: () => _showDetail(context, vm, job),
                                  ),
                                  if (job.referenceType == 'RESERVATION' && job.referenceId != null)
                                    AppButton(
                                      label: '관련 예약',
                                      expand: false,
                                      variant: AppButtonVariant.secondary,
                                      onPressed: () => pushPage<void>(
                                        context,
                                        AdminReservationDetailScreen(storeId: ctx.storeId, reservationId: job.referenceId!),
                                      ),
                                    ),
                                  if (job.canRetry)
                                    AppButton(
                                      label: '무시 처리',
                                      expand: false,
                                      variant: AppButtonVariant.text,
                                      loading: vm.isBusy('ignore:${job.id}'),
                                      onPressed: () async {
                                        final reason = await showReasonDialog(
                                          context,
                                          title: '이 작업을 무시할까요?',
                                          message: '다시 처리하지 않고 확인 완료로 표시해요. 고객에게 직접 안내했다면 사유에 남겨 주세요.',
                                          presets: const ['고객에게 전화로 직접 안내 완료', '이미 해결된 건'],
                                          confirmLabel: '무시 처리',
                                          maxLength: 1000,
                                        );
                                        if (reason != null) await vm.ignore(job.id, reason);
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
