import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../../widgets/star_rating.dart';
import '../domain/defect_type.dart';
import '../domain/review.dart';

/// 리뷰 작성. DESIGN.md 3장
///
/// 맛평가 / 제품평가를 토글로 고른다. 맛평가가 기본 ON, 둘 다 켜도 되고
/// 하나만 켜도 되며 최소 하나는 필수다.
///
/// 이렇게 나눈 이유: 배송 중 국물이 새거나 상해서 온 사고가 맛 점수를
/// 오염시키지 않게 하려는 것이다. 하자로 맛을 제대로 못 본 경우
/// 제품평가만 켜서 신고하면 맛 점수는 남지 않는다.
class ReviewFormPage extends ConsumerStatefulWidget {
  const ReviewFormPage({super.key, required this.kimchiId});

  final String kimchiId;

  @override
  ConsumerState<ReviewFormPage> createState() => _ReviewFormPageState();
}

class _ReviewFormPageState extends ConsumerState<ReviewFormPage> {
  bool _tasteOn = true;
  bool _defectOn = false;

  double? _score;

  /// 맛 프로필 3축은 선택 입력이다. 켜지 않으면 저장하지 않는다.
  bool _profileOn = false;
  double _spicy = 5;
  double _sweet = 5;
  double _fishiness = 5;

  final _comment = TextEditingController();
  final _defectNote = TextEditingController();
  final _defectTypes = <String>{};

  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _comment.dispose();
    _defectNote.dispose();
    super.dispose();
  }

  /// 이미 쓴 리뷰가 있으면 그 값으로 채운다 (1인 1리뷰 + 수정 가능)
  void _prefill(Review review) {
    _prefilled = true;
    _tasteOn = review.hasTaste;
    _defectOn = review.hasDefect;
    _score = review.scoreOverall;
    _comment.text = review.comment ?? '';
    _defectTypes
      ..clear()
      ..addAll(review.defectTypes);
    _defectNote.text = review.defectNote ?? '';

    if (review.hasProfile) {
      _profileOn = true;
      _spicy = review.scoreSpicy!.toDouble();
      _sweet = review.scoreSweet!.toDouble();
      _fishiness = review.scoreFishiness!.toDouble();
    }
  }

  String? _validate() {
    if (!_tasteOn && !_defectOn) return '맛평가 또는 제품평가 중 하나는 선택해야 합니다';
    if (_tasteOn && _score == null) return '종합 만족도(별점)를 매겨주세요';
    if (_defectOn && _defectTypes.isEmpty) return '하자 유형을 하나 이상 골라주세요';
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(reviewRepositoryProvider).save(
        ReviewDraft(
          kimchiId: widget.kimchiId,
          scoreOverall: _tasteOn ? _score : null,
          scoreSpicy: _tasteOn && _profileOn ? _spicy.round() : null,
          scoreSweet: _tasteOn && _profileOn ? _sweet.round() : null,
          scoreFishiness: _tasteOn && _profileOn ? _fishiness.round() : null,
          comment: _tasteOn ? _comment.text : null,
          defectTypes: _defectOn ? _defectTypes.toList() : const [],
          defectNote: _defectOn ? _defectNote.text : null,
        ),
      );

      invalidateKimchi(ref, widget.kimchiId);
      messenger.showSnackBar(const SnackBar(content: Text('평가를 저장했습니다')));
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('저장하지 못했습니다: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String reviewId) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('평가를 삭제할까요?'),
        content: const Text('삭제하면 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(reviewRepositoryProvider).delete(reviewId);
      invalidateKimchi(ref, widget.kimchiId);
      messenger.showSnackBar(const SnackBar(content: Text('평가를 삭제했습니다')));
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('삭제하지 못했습니다: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(myReviewProvider(widget.kimchiId)).value;
    if (existing != null && !_prefilled) _prefill(existing);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? '평가하기' : '평가 수정'),
        actions: [
          if (existing != null)
            IconButton(
              onPressed: () => _delete(existing.id),
              icon: const Icon(Icons.delete_outline),
              tooltip: '삭제',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _tasteOn,
            onChanged: (value) => setState(() => _tasteOn = value),
            title: const Text('맛평가'),
            subtitle: const Text('맛이 어땠는지 별점으로 남깁니다'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _defectOn,
            onChanged: (value) => setState(() => _defectOn = value),
            title: const Text('제품평가 (하자 신고)'),
            subtitle: const Text('포장 파손·변질 등 받은 제품의 문제를 신고합니다'),
          ),

          if (_tasteOn) ...[
            const Divider(height: 32),
            Text('종합 만족도', style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              '전반적으로 얼마나 맛있었나요? (필수)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StarRatingInput(
                  score: _score,
                  onChanged: (value) => setState(() => _score = value),
                ),
                const SizedBox(width: 12),
                Text(
                  _score == null ? '' : _score!.toStringAsFixed(1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _profileOn,
              onChanged: (value) => setState(() => _profileOn = value),
              title: const Text('맛 프로필도 입력 (선택)'),
              subtitle: const Text('매운맛·단맛·젓갈맛 — 취향 매칭에 쓰입니다'),
            ),
            if (_profileOn) ...[
              _AxisSlider(
                label: '매운맛',
                value: _spicy,
                onChanged: (value) => setState(() => _spicy = value),
              ),
              _AxisSlider(
                label: '단맛',
                value: _sweet,
                onChanged: (value) => setState(() => _sweet = value),
              ),
              _AxisSlider(
                label: '젓갈맛',
                value: _fishiness,
                onChanged: (value) => setState(() => _fishiness = value),
              ),
              Text(
                '세 축은 좋고 나쁨이 아니라 "어떤 맛인지"를 뜻합니다. 순위에는 반영되지 않습니다.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '코멘트 (선택)',
                hintText: '어떤 점이 좋았는지 한두 줄 남겨주세요',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],

          if (_defectOn) ...[
            const Divider(height: 32),
            Text('하자 유형', style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              '해당하는 것을 모두 골라주세요 (1개 이상)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in DefectType.values)
                  FilterChip(
                    label: Text(type.label),
                    selected: _defectTypes.contains(type.code),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _defectTypes.add(type.code)
                          : _defectTypes.remove(type.code);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _defectNote,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '하자 설명 (선택)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '하자 신고는 정보로만 표시되고 맛 점수나 순위에는 반영되지 않습니다.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _AxisSlider extends StatelessWidget {
  const _AxisSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
