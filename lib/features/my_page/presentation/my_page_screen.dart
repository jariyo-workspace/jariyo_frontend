import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get_it/get_it.dart';

import '../../../app/session_controller.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../auth/domain/auth_entities.dart';
import '../../home/presentation/my_activity_screen.dart';
import '../../notification/presentation/notification_settings_screen.dart';
import '../../store/domain/store_repository.dart';
import '../../store/domain/store_usecases.dart';
import '../../store/presentation/store_detail_screen.dart';

/// C-20 마이페이지
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = GetIt.I<SessionController>();
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final profile = session.profile;
        return Scaffold(
          appBar: AppBar(title: const Text('마이페이지')),
          body: profile == null ? _guest(session) : _signedIn(context, session, profile),
        );
      },
    );
  }

  Widget _guest(SessionController session) => EmptyView(
    icon: Icons.person_outline,
    title: '로그인이 필요해요',
    message: '로그인하면 예약 내역과 알림 설정을 관리할 수 있어요.',
    actionLabel: '로그인',
    onAction: session.requestSignIn,
  );

  Widget _signedIn(BuildContext context, SessionController session, UserProfile profile) {
    final recent = RecentStores(GetIt.I<StoreRepository>()).get();
    return RefreshIndicator(
      onRefresh: () => session.reloadProfile().catchError((Object e) {
        if (e is AppFailure) AppMessenger.showFailure(e);
      }),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: AppColors.primary.withAlpha(40), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'assets/icons/person.svg',
                      width: 36,
                      colorFilter: const ColorFilter.mode(AppColors.primary, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(profile.email, style: const TextStyle(color: AppColors.lightText)),
                        Text(profile.phoneNumber, style: const TextStyle(color: AppColors.lightText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (profile.canOperateStore) ...[
            const SizedBox(height: 12),
            Card(
              color: AppColors.primary.withAlpha(16),
              child: ListTile(
                leading: const Icon(Icons.storefront, color: AppColors.primary),
                title: const Text('매장 운영 화면으로 전환', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('소속 매장 ${profile.activeMemberships.length}곳'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => pickOperatorStore(context, session),
              ),
            ),
          ],
          const SectionTitle('내 정보'),
          _Menu(
            children: [
              _tile(Icons.phone_outlined, '연락처 관리', subtitle: profile.phoneNumber, onTap: () {
                AppMessenger.show('연락처 변경 기능은 준비 중이에요.');
              }),
              _tile(Icons.notifications_outlined, '알림 설정', onTap: () {
                pushPage<void>(context, const NotificationSettingsScreen());
              }),
              _tile(Icons.privacy_tip_outlined, '개인정보 설정', onTap: () => _showPrivacy(context, profile)),
            ],
          ),
          const SectionTitle('이용'),
          _Menu(
            children: [
              _tile(Icons.receipt_long_outlined, '이용 내역', onTap: () {
                pushPage<void>(context, const MyActivityScreen(standalone: true, initialTab: 3));
              }),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SectionTitle('최근 이용 매장'),
            _Menu(
              children: [
                for (final store in recent.take(5))
                  _tile(Icons.store_outlined, store.name, subtitle: store.address, onTap: () {
                    pushPage<void>(context, StoreDetailScreen(storeId: store.id));
                  }),
              ],
            ),
          ],
          const SectionTitle('계정'),
          _Menu(
            children: [
              _tile(Icons.logout, '로그아웃', onTap: () async {
                final ok = await showConfirmDialog(
                  context,
                  title: '로그아웃할까요?',
                  message: '다시 로그인하면 예약과 대기 정보를 그대로 볼 수 있어요.',
                  confirmLabel: '로그아웃',
                );
                if (ok) await session.signOut();
              }),
              _tile(Icons.person_remove_outlined, '회원 탈퇴', color: AppColors.danger, onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('회원 탈퇴'),
                    content: const Text(
                      '회원 탈퇴 기능은 준비 중이에요.\n탈퇴 전 진행 중인 예약과 대기를 먼저 취소해 주세요.',
                      style: TextStyle(height: 1.5),
                    ),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, {String? subtitle, Color? color, required VoidCallback onTap}) => ListTile(
    leading: Icon(icon, color: color ?? AppColors.text),
    title: Text(title, style: TextStyle(color: color ?? AppColors.text)),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.keyboard_arrow_right),
    onTap: onTap,
  );

  void _showPrivacy(BuildContext context, UserProfile profile) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개인정보 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoRow(label: '서비스 알림', value: profile.notificationConsent ? '동의' : '미동의'),
            InfoRow(label: '마케팅 수신', value: profile.marketingConsent ? '동의' : '미동의'),
            const SizedBox(height: 8),
            const Text('알림 수신 여부는 알림 설정에서 바꿀 수 있어요.', style: TextStyle(color: AppColors.lightText)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }
}

/// 소속 매장 중 하나를 골라 운영 화면으로 전환한다. (A-01)
Future<void> pickOperatorStore(BuildContext context, SessionController session) async {
  final memberships = session.profile?.activeMemberships ?? const <StoreMembership>[];
  if (memberships.isEmpty) return;
  if (memberships.length == 1) {
    await session.enterOperator(memberships.first.storeId);
    return;
  }
  final getStore = GetStoreDetail(GetIt.I<StoreRepository>());
  final names = await Future.wait(
    memberships.map((m) => getStore(m.storeId).then((s) => s.name).catchError((_) => '매장 ${m.storeId.substring(0, 6)}')),
  );
  if (!context.mounted) return;
  final storeId = await showChoiceSheet<String>(
    context,
    title: '운영할 매장을 선택해 주세요',
    options: [
      for (var i = 0; i < memberships.length; i++) (memberships[i].storeId, names[i], memberships[i].role.label),
    ],
    selected: session.operatorStoreId,
  );
  if (storeId != null) await session.enterOperator(storeId);
}

class _Menu extends StatelessWidget {
  const _Menu({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) const Divider(height: 1, indent: 56), children[i]],
      ],
    ),
  );
}
