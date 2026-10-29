import '../../../core/domain/paged.dart';
import 'admin_entities.dart';
import 'admin_repositories.dart';

class GetAnalyticsReport {
  const GetAnalyticsReport(this._repository);

  final AdminInsightsRepository _repository;

  Future<AnalyticsReport> call(String storeId, {required DateTime from, required DateTime to}) =>
      _repository.analytics(storeId, from: from, to: to);
}

class GetAuditLogs {
  const GetAuditLogs(this._repository);

  final AdminInsightsRepository _repository;

  Future<Paged<AuditLogEntry>> call(
    String storeId, {
    String? action,
    String? targetType,
    String? targetId,
    DateTime? from,
    DateTime? to,
    String? cursor,
  }) => _repository.auditLogs(
    storeId,
    action: action,
    targetType: targetType,
    targetId: targetId,
    from: from,
    to: to,
    cursor: cursor,
  );
}

class GetFailedJobs {
  const GetFailedJobs(this._repository);

  final AdminInsightsRepository _repository;

  Future<Paged<FailedJob>> call(String storeId, {FailedJobStatus? status, String? cursor}) =>
      _repository.failedJobs(storeId, status: status, cursor: cursor);
}

class GetFailedJob {
  const GetFailedJob(this._repository);

  final AdminInsightsRepository _repository;

  Future<FailedJob> call(String storeId, String jobId) => _repository.failedJob(storeId, jobId);
}

class ResolveFailedJob {
  const ResolveFailedJob(this._repository);

  final AdminInsightsRepository _repository;

  Future<void> retry(String storeId, String jobId, {required String idempotencyKey}) =>
      _repository.retryFailedJob(storeId, jobId, idempotencyKey: idempotencyKey);

  Future<void> ignore(String storeId, String jobId, {required String reason}) =>
      _repository.ignoreFailedJob(storeId, jobId, reason: reason);
}
