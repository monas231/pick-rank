import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pick_rank/app.dart';
import 'package:pick_rank/core/env.dart';
import 'package:pick_rank/features/reviews/domain/defect_type.dart';
import 'package:pick_rank/features/reviews/domain/review.dart';
import 'package:pick_rank/widgets/taste_radar_chart.dart';

void main() {
  test('테스트 환경에는 Supabase 키가 없다', () {
    expect(Env.isConfigured, isFalse);
  });

  testWidgets('키가 없으면 설정 안내 화면이 뜬다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PickRankApp()));
    expect(find.text('Supabase 연결 정보가 없습니다'), findsOneWidget);
  });

  testWidgets('맛 프로필 레이더 차트가 그려진다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TasteRadarChart(spicy: 8, sweet: 3, fishiness: 6),
        ),
      ),
    );
    expect(find.byType(TasteRadarChart), findsOneWidget);
  });

  group('ReviewDraft 유효성 — 맛평가·제품평가 중 최소 하나 (DESIGN.md 3장)', () {
    test('별점만 있어도 유효하다', () {
      const draft = ReviewDraft(kimchiId: 'k', scoreOverall: 4.5);
      expect(draft.isValid, isTrue);
    });

    test('하자 신고만 있어도 유효하다', () {
      const draft = ReviewDraft(
        kimchiId: 'k',
        defectTypes: ['packaging_damage'],
      );
      expect(draft.isValid, isTrue);
    });

    test('둘 다 없으면 유효하지 않다', () {
      const draft = ReviewDraft(kimchiId: 'k', comment: '맛있어요');
      expect(draft.isValid, isFalse);
    });

    test('빈 코멘트는 null 로 보낸다', () {
      const draft = ReviewDraft(kimchiId: 'k', scoreOverall: 4, comment: '   ');
      expect(draft.toMap('u')['comment'], isNull);
    });

    test('하자 유형이 비면 null 로 보낸다 (빈 배열은 DB CHECK 위반)', () {
      const draft = ReviewDraft(kimchiId: 'k', scoreOverall: 4);
      expect(draft.toMap('u')['defect_types'], isNull);
    });
  });

  test('하자 유형 코드는 DB defect_type_meta 와 같은 값을 쓴다', () {
    expect(
      DefectType.values.map((type) => type.code).toList(),
      equals([
        'packaging_damage',
        'spoilage',
        'foreign_object',
        'manufacturing_defect',
        'delivery_issue',
        'other',
      ]),
    );
  });
}
