import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 상품 이미지. DB에는 경로만 있고 URL은 조회 시 만든다 (DESIGN.md 8.1).
/// 아직 이미지를 올리지 않은 카탈로그가 많으므로 빈 상태를 기본으로 취급한다.
class KimchiThumbnail extends StatelessWidget {
  const KimchiThumbnail({super.key, required this.url, this.size = 64});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: size,
      height: size,
      color: scheme.surfaceContainerHighest,
      child: Icon(
        Icons.ramen_dining_outlined,
        size: size * 0.4,
        color: scheme.onSurfaceVariant,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => placeholder,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}
