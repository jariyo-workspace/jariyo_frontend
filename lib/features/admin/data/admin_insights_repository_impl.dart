import '../../../core/domain/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/common_mappers.dart';
import '../../../core/utils/date_time_format.dart';
import '../domain/admin_entities.dart';
import '../domain/admin_repositories.dart';
import 'admin_mappers.dart';

class AdminInsightsRepositoryImpl implements AdminInsightsRepository {
  const AdminInsightsRepositoryImpl(this._api);

  final ApiClient _api;

  String _base(String storeId) => '/admin/stores/$storeId';

  @override
  Future<AnalyticsReport> analytics(String storeId, {required DateTime from, required DateTime to}) async {
    final query = {'from': formatYmd(from), 'to': formatYmd(to)};
    final results = await Future.wait([
      _api.get('${_base(storeId)}/analytics/summary', query: query),
      _api.get('${_base(storeId)}/analytics/reservations/daily', query: query),
      _api.get('${_base(storeId)}/analytics/staff', query: query),
      _api.get('${_base(storeId)}/analytics/services/duration', query: query),
    ]);
    return AnalyticsReport(
      summary: analyticsSummaryFromJson(results[0].json),
      daily: results[1].list.map(dailyStatFromJson).toList(),
      staff: results[2].list.map(staffStatFromJson).toList(),
      services: results[3].list.map(serviceDurationFromJson).toList(),
    );
  }

  @override
  Future<Paged<AuditLogEntry>> auditLogs(
    String storeId, {
    String? action,
    String? targetType,
    String? targetId,
    DateTime? from,
    DateTime? to,
    String? cursor,
  }) async => pagedFrom(
    await _api.get(
      '${_base(storeId)}/audit-logs',
      query: {
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'from': from?.toUtc().toIso8601String(),
        'to': to?.toUtc().toIso8601String(),
        'cursor': cursor,
        'limit': 50,
      },
    ),
    auditLogFromJson,
  );

  @override
  Future<Paged<FailedJob>> failedJobs(String storeId, {FailedJobStatus? status, String? cursor}) async => pagedFrom(
    await _api.get('${_base(storeId)}/failed-jobs', query: {'status': status?.code, 'cursor': cursor, 'limit': 50}),
    failedJobFromJson,
  );

  @override
  Future<FailedJob> failedJob(String storeId, String jobId) async =>
      failedJobFromJson((await _api.get('${_base(storeId)}/failed-jobs/$jobId')).json);

  @override
  Future<void> retryFailedJob(String storeId, String jobId, {required String idempotencyKey}) =>
      _api.post('${_base(storeId)}/failed-jobs/$jobId/retry', idempotencyKey: idempotencyKey);

  @override
  Future<void> ignoreFailedJob(String storeId, String jobId, {required String reason}) =>
      _api.post('${_base(storeId)}/failed-jobs/$jobId/ignore', body: {'reason': reason});
}
