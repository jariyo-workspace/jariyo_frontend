import '../../../core/domain/statuses.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    this.notificationConsent = true,
    this.marketingConsent = false,
    this.memberships = const [],
  });

  final String id;
  final String email;
  final String displayName;
  final String phoneNumber;
  final bool notificationConsent;
  final bool marketingConsent;
  final List<StoreMembership> memberships;

  /// 고객과 매장 멤버 역할은 별도로 판단한다. 활성 매장 멤버십이 있으면 운영 화면을 쓸 수 있다.
  List<StoreMembership> get activeMemberships => memberships.where((m) => m.isActive).toList();

  bool get canOperateStore => activeMemberships.isNotEmpty;

  StoreMembership? membershipFor(String storeId) =>
      activeMemberships.where((m) => m.storeId == storeId).firstOrNull;
}

class StoreMembership {
  const StoreMembership({required this.storeId, required this.role, required this.status});

  final String storeId;
  final StoreRole role;
  final MemberStatus status;

  bool get isActive => status == MemberStatus.active;
}

class SignUpParams {
  const SignUpParams({
    required this.email,
    required this.password,
    required this.displayName,
    required this.phoneNumber,
    required this.agreeTerms,
    required this.agreePrivacy,
    required this.agreeMarketing,
  });

  final String email;
  final String password;
  final String displayName;
  final String phoneNumber;
  final bool agreeTerms;
  final bool agreePrivacy;
  final bool agreeMarketing;
}
