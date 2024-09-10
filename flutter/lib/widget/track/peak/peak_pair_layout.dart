import 'package:flutter/material.dart';
import 'package:flutter_smart_genome/bean/feature_beans.dart';
import 'package:d4_scale/d4_scale.dart';
import 'package:flutter_smart_genome/d3/d3_mixin.dart';
import 'package:flutter_smart_genome/page/track/track_ui_config_bean.dart';
import 'package:flutter_smart_genome/service/beans.dart';
import 'package:flutter_smart_genome/widget/track/base/layout/layout_base.dart';
import 'package:flutter_smart_genome/widget/track/base/layout/track_layout_manager.dart';
import 'package:flutter_smart_genome/widget/track/common.dart';
import 'package:dartx/dartx.dart' as dx;

class PeakPairLayout extends TrackLayout {
  Map<int, FeaturePosition> rowLastBlockPositionsMap = {};

  Map<String, int> featureRowMap = {};

  double maxHeight = 0;

  PeakPairLayout() {}

  clear() {
    int length = featureRowMap.length;
    rowLastBlockPositionsMap.clear();
    featureRowMap.clear();
    maxHeight = 0;
    print('clear => $length');
  }

  void calculate({
    required List<PeakPair> peakPairs,
    required double rowHeight,
    required double rowSpace,
    required Scale<num, num> scale,
    required Axis orientation,
    required TrackCollapseMode collapseMode,
    required bool showLabel,
    required double labelFontSize,
    required Range visibleRange,
    EdgeInsets padding = EdgeInsets.zero,
    required bool coAccessibility,
    bool drawDown = true,
  }) {
    if ((peakPairs.length ?? 0) == 0) return;

    Map<int, List<FeaturePosition>> _rowFeaturePositionList = {};

    bool _horizontal = orientation == Axis.horizontal;
    //print('scale $scale visible range: $visibleRange');
    PeakPair feature;
    int _featureRow;
    double top;

    bool _showLabel = showLabel && labelFontSize > 0;
    rowSpace = _showLabel ? rowSpace : 5;
    double minWidth = _showLabel ? 5 : 2;

    int _direction = drawDown ? 1 : -1;

    for (int i = 0; i < peakPairs.length; i++) {
      feature = peakPairs[i]; //..linkPath = null;
      feature.index = i;

      Range range = feature.range;
      double start = scale[range.start]!;
      double end = scale[range.end]!;

      double fHeight = rowHeight;
      _featureRow = 0;

      top = padding.top;
      Rect fRect = _horizontal ? Rect.fromLTRB(start, top, end, top + fHeight) : Rect.fromLTRB(top, start, top + fHeight, end);

      feature.row = _featureRow;
      feature.groupRect = fRect;
      feature.rect = fRect;

      Offset left = drawDown ? fRect.topLeft : fRect.bottomLeft;
      Offset right = drawDown ? fRect.topRight : fRect.bottomRight;
      Offset center = Offset(left.dx + (right.dx - left.dx) / 2, left.dy);
      feature.linkPath = Path()
        ..moveTo(left.dx, left.dy)
        // ..quadraticBezierTo(center.dx, center.dy + (rowHeight + 100) * _direction, right.dx, right.dy);
        // ..cubicTo((left.dx + center.dx) / 2, left.dy + (rowHeight + 50) * _direction, (center.dx + right.dx) / 2, center.dy + (rowHeight + 50) * _direction, right.dx, right.dy);
        ..conicTo(center.dx, center.dy + (rowHeight + 50) * _direction, right.dx, right.dy, 2.0 * feature.value);
    }
    maxHeight = rowHeight;
  }

  double _measureBlockMaxEnd(List<Feature> features, Scale<num, num> scale, double labelFontSize) {
    return features.map((f) {
      double s = scale[f.range.start] as double;
      double e = scale[f.range.end] as double;
      String maxLabel = f.name;
      double textWidth = measureTextWidth(maxLabel, labelFontSize) + 10;
      f.labelWidth = textWidth;
      double delta = textWidth - (e - s);
      return delta > 0 ? e + delta : e;
    }).max()!;
  }

  int _findMaxRowInMap(double start, Map<int, List<FeaturePosition>> map) {
    if (map.length == 0) return 0;
    return map.values.map((e) => _findMaxRow(start, e)).reduce((a, b) => a > b ? a : b);
  }

  int? _findProperPositionRow(id, start, end, height, rowHeight, rowSpace, EdgeInsets padding, childrenCount, Map<int, List<FeaturePosition>> rowFeatureList) {
    bool _overlapRows(List<int> rows, Rect rect) {
      bool overlap = false;
      for (int row in rows) {
        List<FeaturePosition> _positions = rowFeatureList[row]!;
        if (_rangeInteract(rect, _positions)) {
          overlap = true;
          break;
        }
      }
      return overlap;
    }

    Rect rect;
    int? _row = null;
    if (rowFeatureList.keys.length == 0) return 0;

    int maxRow = rowFeatureList.keys.reduce((a, b) => a > b ? a : b);

    for (int row = 0; row <= maxRow; row++) {
      if (!rowFeatureList.containsKey(row)) {
        _row = row;
        break;
      }
//      List<BlockPosition> _positions = rowFeatureList[row];
      double top = (row) * rowHeight + (row) * rowSpace + padding.top;
      rect = Rect.fromLTRB(start, top, end, top + height);

      //如果是多行，还要找下面几行是不是也没交集
      List<int> _rows = childrenCount > 0 ? List.generate(childrenCount + 1, (index) => row + index) : [row];
      if (!_overlapRows(_rows, rect)) {
        _row = row;
        break;
      }

//      if (childrenCount > 0) {
//        row += (childrenCount - 1);
//      }
    }
    if (null == _row) _row = maxRow + 1;
    //print('===============> find proper row ${id} => $_row  ${maxRow + 1}');
    return _row;
  }

  bool _rangeInteract(Rect rect, List<FeaturePosition> _positions) {
    if (_positions.isEmpty) return false;
    bool interact = false;
    for (FeaturePosition position in _positions) {
      if (position.rect.overlaps(rect)) {
        interact = true;
        break;
      }
    }
    return interact;
  }

  int _findMaxRow(double start, Iterable<FeaturePosition> blockPositions) {
    Iterable<FeaturePosition> _blockPositions = blockPositions.where((p) => !(p.rect.right < start));
    if (_blockPositions.isEmpty) return 0;

    FeaturePosition _position = _blockPositions.reduce((value, element) => value.row > element.row ? value : element);
    return _position.row;
  }

  double _findMaxHeight(Iterable<FeaturePosition> blockPositions, bool _horizontal) {
    if (blockPositions.isEmpty) return 0;
    if (_horizontal) {
      return blockPositions.reduce((value, element) => value.rect.bottom > element.rect.bottom ? value : element).rect.bottom;
    } else {
      return blockPositions.reduce((value, element) => value.rect.right > element.rect.right ? value : element).rect.right;
    }
  }

  double _injectFeatureRect(
    Feature feature,
    Rect rect,
    bool _horizontal,
    double rowHeight,
    double rowSpace,
    Scale<num, num> scale,
    TrackCollapseMode collapseMode,
    bool showLabel,
    double labelFontSize,
  ) {
    if (!feature.hasSubFeature) return 0;
    for (Feature feature in feature.subFeatures!) {
      feature.rect = _horizontal
          ? Rect.fromLTRB(scale[feature.range.start]!, rect.top, scale[feature.range.end]!, rect.bottom) //
          : Rect.fromLTRB(rect.left, scale[feature.range.start]!, rect.right, scale[feature.range.end]!);
      if (feature.subFeatures != null) {
        _injectFeatureRect(feature, feature.rect!, _horizontal, rowHeight, rowSpace, scale, collapseMode, showLabel, labelFontSize);
      }
    }
    return 0;
  }
}
