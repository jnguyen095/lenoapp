import 'package:flutter/widgets.dart';

/// Kích thước màn hình: điện thoại / máy tính bảng (dọc, ngang) / desktop.
class Layout {
  Layout._(this.size);

  factory Layout.of(BuildContext context) => Layout._(MediaQuery.sizeOf(context));

  final Size size;

  /// Máy tính bảng (cạnh ngắn ≥ 600 dp, gồm cả cửa sổ desktop).
  bool get isTablet => size.shortestSide >= 600;

  /// Đủ rộng để đặt thực đơn và món đã gọi cạnh nhau (tablet ngang và tablet dọc 8"+).
  bool get splitOrder => size.width >= 720;

  /// Bề rộng cột "Món đã gọi" khi chia đôi màn hình.
  double get orderPanelWidth => (size.width * 0.42).clamp(340.0, 480.0);

  double get gridSpacing => isTablet ? 12 : 10;
  EdgeInsets get pagePadding => EdgeInsets.all(isTablet ? 16 : 12);

  /// Sơ đồ bàn: tablet cố định 6 bàn một hàng; điện thoại tự chia cột.
  SliverGridDelegate get tableGrid => isTablet
      ? SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisExtent: 104,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
        )
      : SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 130,
          mainAxisExtent: 100,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
        );

  /// Thực đơn: tablet cố định 5 món một hàng; điện thoại tự chia cột (thường 3).
  /// Chiều cao ô tính theo bề rộng thật của ô: ảnh thấp hơn bề rộng + 40 cho tên món.
  SliverGridDelegate productGrid(double availableWidth) {
    final columns = isTablet ? 5 : ((availableWidth - pagePadding.horizontal + gridSpacing) / (150 + gridSpacing)).ceil().clamp(2, 4);
    final tileWidth = (availableWidth - pagePadding.horizontal - gridSpacing * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisExtent: (tileWidth * 0.72).clamp(70.0, 150.0) + 40,
      crossAxisSpacing: gridSpacing,
      mainAxisSpacing: gridSpacing,
    );
  }
}
