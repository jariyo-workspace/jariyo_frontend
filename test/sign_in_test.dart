import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jariyo_frontend/core/strings.dart';
import 'package:jariyo_frontend/main.dart';

void main() {
  testWidgets('빈 입력이면 필드 아래 오류를 표시하고 요청하지 않는다', (tester) async {
    await tester.pumpWidget(const JariyoApp());
    await tester.tap(find.widgetWithText(FilledButton, S.signInSubmit));
    await tester.pump();
    expect(find.text(S.signInEmailRequired), findsOneWidget);
    expect(find.text(S.signInPasswordRequired), findsOneWidget);
  });

  testWidgets('이메일 형식 검사', (tester) async {
    await tester.pumpWidget(const JariyoApp());
    await tester.enterText(find.byType(TextField).first, '  abc  ');
    await tester.tap(find.widgetWithText(FilledButton, S.signInSubmit));
    await tester.pump();
    expect(find.text(S.signInEmailInvalid), findsOneWidget);
  });

  testWidgets('360dp 폭에서도 넘침 없이 렌더링된다', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const JariyoApp());
    expect(tester.takeException(), isNull);
    expect(find.text(S.appCopyright), findsOneWidget);
  });
}
