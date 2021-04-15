// Copyright 2021 Ron Booth. All rights reserved.
// Use of this source code is governed by a license that can be found in the LICENSE file.

import 'package:float_column/src/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'float_tag.dart';
import 'render_paragraph.dart';
import 'shared.dart';
import 'wrappable_text.dart';

/// Parent data for use with [RenderFloatColumn].
class FloatColumnParentData extends ContainerBoxParentData<RenderBox> {
  /// The scaling of the text.
  double? scale;

  @override
  String toString() {
    final values = <String>[
      'offset=$offset',
      if (scale != null) 'scale=$scale',
      super.toString(),
    ];
    return values.join('; ');
  }
}

/// A render object that displays a vertical list of widgets and paragraphs of text.
///
/// ## Layout algorithm
///
/// _This section describes how the framework causes [RenderFloatColumn] to position
/// its children._
/// _See [BoxConstraints] for an introduction to box layout models._
///
/// Layout for a [RenderFloatColumn] proceeds in six steps:
///
/// 1. Layout each child with unbounded main axis constraints and the incoming
///    cross axis constraints. If the [crossAxisAlignment] is
///    [CrossAxisAlignment.stretch], instead use tight cross axis constraints
///    that match the incoming max extent in the cross axis.
///
/// 2. The cross axis extent of the [RenderFloatColumn] is the maximum cross axis
///    extent of the children (which will always satisfy the incoming
///    constraints).
///
/// 3. The main axis extent of the [RenderFloatColumn] is the sum of the main axis
///    extents of the children (subject to the incoming constraints).
///
class RenderFloatColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, FloatColumnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, FloatColumnParentData>,
        DebugOverflowIndicatorMixin {
  /// Creates a FloatColumn render object.
  ///
  /// By default, the children are aligned to the start of the cross axis.
  RenderFloatColumn(
    this._textAndWidgets, {
    required CrossAxisAlignment crossAxisAlignment,
    required TextDirection? textDirection,
    required DefaultTextStyle defaultTextStyle,
    required double defaultTextScaleFactor,
    Clip clipBehavior = Clip.none,
    List<RenderBox>? widgets,
  })  : assert(crossAxisAlignment != null), // ignore: unnecessary_null_comparison
        assert(clipBehavior != null), // ignore: unnecessary_null_comparison
        _internalTextAndWidgets = _textAndWidgets,
        _crossAxisAlignment = crossAxisAlignment,
        _textDirection = textDirection,
        _defaultTextStyle = defaultTextStyle,
        _defaultTextScaleFactor = defaultTextScaleFactor,
        _clipBehavior = clipBehavior {
    addAll(widgets);
    _updateCache();
  }

  // List<Object> get textAndWidgets => _textAndWidgets;
  List<Object> _textAndWidgets;
  List<Object> _internalTextAndWidgets;
  // ignore: avoid_setters_without_getters
  set textAndWidgets(List<Object> value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    if (_textAndWidgets != value) {
      _internalTextAndWidgets = _textAndWidgets = value;
      _updateCache();
      markNeedsLayout();
    }
  }

  final _cache = <Object, RenderParagraphHelper>{};
  void _updateCache() {
    final keys = <Object>{};
    for (var i = 0; i < _internalTextAndWidgets.length; i++) {
      var el = _internalTextAndWidgets[i];
      if (el is WrappableText) {
        // The key MUST be unique, so if it is not, make it so...
        if (keys.contains(el.key)) {
          var k = -i;
          var newKey = ValueKey(k);
          while (keys.contains(newKey)) {
            newKey = ValueKey(--k);
          }
          el = el.copyWith(key: newKey);

          // Before we make a change to `_internalTextAndWidgets`, make sure it is a copy.
          if (identical(_internalTextAndWidgets, _textAndWidgets)) {
            _internalTextAndWidgets = List<Object>.of(_textAndWidgets);
          }

          _internalTextAndWidgets[i] = el;
        }

        keys.add(el.key);
        final prh = _cache[el.key];
        if (prh == null) {
          _cache[el.key] =
              RenderParagraphHelper(el, textDirection, defaultTextStyle, defaultTextScaleFactor);
        } else {
          prh.updateWith(el, this, textDirection, defaultTextStyle, defaultTextScaleFactor);
        }
      }
    }

    _cache.removeWhere((key, value) => !keys.contains(key));
  }

  /// How the children should be placed along the cross axis.
  ///
  /// If the [crossAxisAlignment] is either [CrossAxisAlignment.start] or
  /// [CrossAxisAlignment.end], then the [textDirection] must not be null.
  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  CrossAxisAlignment _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    if (_crossAxisAlignment != value) {
      _crossAxisAlignment = value;
      markNeedsLayout();
    }
  }

  /// Controls the meaning of the [crossAxisAlignment] property's
  /// [CrossAxisAlignment.start] and [CrossAxisAlignment.end] values.
  ///
  /// If the [crossAxisAlignment] is either [CrossAxisAlignment.start] or
  /// [CrossAxisAlignment.end], then the [textDirection] must not be null.
  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection != value) {
      _textDirection = value;
      _updateCache();
      markNeedsLayout();
    }
  }

  DefaultTextStyle get defaultTextStyle => _defaultTextStyle;
  DefaultTextStyle _defaultTextStyle;
  set defaultTextStyle(DefaultTextStyle value) {
    if (_defaultTextStyle != value) {
      _defaultTextStyle = value;
      _updateCache();
      markNeedsLayout();
    }
  }

  double get defaultTextScaleFactor => _defaultTextScaleFactor;
  double _defaultTextScaleFactor;
  set defaultTextScaleFactor(double value) {
    if (_defaultTextScaleFactor != value) {
      _defaultTextScaleFactor = value;
      _updateCache();
      markNeedsLayout();
    }
  }

  bool get _debugHasNecessaryDirections {
    assert(crossAxisAlignment != null); // ignore: unnecessary_null_comparison
    if (crossAxisAlignment == CrossAxisAlignment.start ||
        crossAxisAlignment == CrossAxisAlignment.end) {
      assert(textDirection != null,
          'Vertical $runtimeType with $crossAxisAlignment has a null textDirection, so the alignment cannot be resolved.');
    }
    return true;
  }

  // Set during layout if overflow occurred on the main axis.
  double _overflow = 0;
  // Check whether any meaningful overflow is present. Values below an epsilon
  // are treated as not overflowing.
  bool get _hasOverflow => _overflow > precisionErrorTolerance;

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.none], and must not be null.
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.none;
  set clipBehavior(Clip value) {
    assert(value != null); // ignore: unnecessary_null_comparison
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void markNeedsLayout() {
    super.markNeedsLayout();
    _overflow = 0;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! FloatColumnParentData) child.parentData = FloatColumnParentData();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  /*
  double _getIntrinsicSize({
    required Axis sizingDirection,
    required double extent, // the extent in the direction that isn't the sizing direction
    required _ChildSizingFunction childSize, // a method to find the size in the sizing direction
  }) {
    if (sizingDirection == Axis.vertical) {
      // INTRINSIC MAIN SIZE
      // Intrinsic main size is the smallest size the container can take
      // while maintaining the min/max-content contributions of its items.

      var totalSize = 0.0;
      var child = firstChild;
      while (child != null) {
        totalSize += childSize(child, extent);
        final childParentData = child.parentData! as FloatColumnParentData;
        child = childParentData.nextSibling;
      }
      return totalSize;
    } else {
      // INTRINSIC CROSS SIZE
      // Intrinsic cross size is the max of the intrinsic cross sizes of the
      // children, after the children are fit into the available space,
      // with the children sized using their max intrinsic dimensions.

      var maxCrossSize = 0.0;
      var child = firstChild;
      while (child != null) {
        late final double mainSize;
        late final double crossSize;
        mainSize = child.getMaxIntrinsicHeight(double.infinity);
        crossSize = childSize(child, mainSize);
        maxCrossSize = math.max(maxCrossSize, crossSize);
        final childParentData = child.parentData! as FloatColumnParentData;
        child = childParentData.nextSibling;
      }
      return maxCrossSize;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _getIntrinsicSize(
      sizingDirection: Axis.horizontal,
      extent: height,
      childSize: (child, extent) => child.getMinIntrinsicWidth(extent),
    );
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _getIntrinsicSize(
      sizingDirection: Axis.horizontal,
      extent: height,
      childSize: (child, extent) => child.getMaxIntrinsicWidth(extent),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return _getIntrinsicSize(
      sizingDirection: Axis.vertical,
      extent: width,
      childSize: (child, extent) => child.getMinIntrinsicHeight(extent),
    );
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _getIntrinsicSize(
      sizingDirection: Axis.vertical,
      extent: width,
      childSize: (child, extent) => child.getMaxIntrinsicHeight(extent),
    );
  }
  */

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(reason: 'Dry layout cannot be efficiently computed.'));
    return Size.zero;

    /*
    final sizes = _computeSizes(
      layoutChild: ChildLayoutHelper.dryLayoutChild,
      constraints: constraints,
    );

    return constraints.constrain(Size(sizes.crossSize, sizes.mainSize));
    */
  }

  @override
  void performLayout() {
    assert(_debugHasNecessaryDirections);

    final constraints = this.constraints;
    final maxWidth = constraints.maxWidth;

    var totalHeight = 0.0;
    var child = firstChild;

    // final flRects = <Rect>[];
    // final frRects = <Rect>[];

    var i = 0;
    for (final el in _internalTextAndWidgets) {
      //---------------------------------------------------------------------
      // If it is a Widget
      //
      if (el is Widget) {
        final tag = child!.tag;
        assert(tag.index == i && tag.placeholderIndex == 0);

        final childParentData = child.parentData! as FloatColumnParentData;
        final BoxConstraints innerConstraints;
        if (crossAxisAlignment == CrossAxisAlignment.stretch) {
          innerConstraints = BoxConstraints.tightFor(width: maxWidth);
        } else {
          innerConstraints = BoxConstraints(maxWidth: maxWidth);
        }
        child.layout(innerConstraints, parentUsesSize: true);
        final childSize = child.size;

        // Does it float?
        if (tag.float != FCFloat.none) {
          // TODO(ron): ...
        }

        final double childCrossPosition;
        switch (_crossAxisAlignment) {
          case CrossAxisAlignment.start:
          case CrossAxisAlignment.end:
            childCrossPosition =
                _crossAxisAlignment == CrossAxisAlignment.start ? 0.0 : maxWidth - child.size.width;
            break;
          case CrossAxisAlignment.center:
            childCrossPosition = maxWidth / 2.0 - child.size.width / 2.0;
            break;
          case CrossAxisAlignment.stretch:
            childCrossPosition = 0.0;
            break;
          case CrossAxisAlignment.baseline:
            childCrossPosition = 0.0;
            break;
        }
        childParentData.offset = Offset(childCrossPosition, totalHeight);

        totalHeight += childSize.height;

        assert(child.parentData == childParentData);
        child = childParentData.nextSibling;
      }

      //---------------------------------------------------------------------
      // Else, if it is a WrappableText
      //
      else if (el is WrappableText) {
        final rph = _cache[el.key]!;

        // If this paragraph does NOT have inline widget children, just layout the text.
        if (child == null || child.tag.index != i) {
          rph.layout(constraints);
        }

        // Else, this paragraph DOES have inline widget children...
        else {
          rph
            // First, set the placeholder dimensions for all the widgets.
            ..setPlaceholderDimensions(
                child, constraints, el.textScaleFactor ?? defaultTextScaleFactor)

            // Next, layout the text and widgets.
            ..layout(constraints);

          // And finally, set the `offset` and `scale` for each widget.
          var widgetIndex = 0;
          while (child != null && child.tag.index == i) {
            assert(child.tag.placeholderIndex == widgetIndex);
            final box = rph.painter.inlinePlaceholderBoxes![widgetIndex];
            final childParentData = child.parentData! as FloatColumnParentData
              ..offset = Offset(box.left, box.top + totalHeight)
              ..scale = rph.painter.inlinePlaceholderScales![widgetIndex];
            child = childParentData.nextSibling;
            widgetIndex++;
          }
        }

        rph.offset = Offset(0, totalHeight);
        totalHeight += rph.painter.height;
      } else {
        assert(false);
      }

      i++;
    }

    size = constraints.constrain(Size(maxWidth, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    var i = 0;
    for (final el in _internalTextAndWidgets) {
      //---------------------------------------------------------------------
      // If it is a Widget
      //
      if (el is Widget) {
        final tag = child!.tag;
        assert(tag.index == i && tag.placeholderIndex == 0);

        final childParentData = child.parentData! as FloatColumnParentData;
        context.paintChild(child, childParentData.offset + offset);
        child = childParentData.nextSibling;

        dmPrint('painted $i, a widget at ${childParentData.offset + offset}');
      }

      //---------------------------------------------------------------------
      // Else, if it is a WrappableText
      //
      else if (el is WrappableText) {
        final rph = _cache[el.key]!;

        dmPrint('painted $i, text at ${rph.offset! + offset}');

        rph.painter.paint(context.canvas, rph.offset! + offset);

        // If this paragraph does NOT have inline widget children, just layout the text.
        if (child == null || child.tag.index != i) {
        }

        // Else, this paragraph DOES have inline widget children...
        else {
          var widgetIndex = 0;
          while (child != null && child.tag.index == i) {
            assert(child.tag.placeholderIndex == widgetIndex);
            final childParentData = child.parentData! as FloatColumnParentData;

            final scale = childParentData.scale!;
            context.pushTransform(
              needsCompositing,
              offset + childParentData.offset,
              Matrix4.diagonal3Values(scale, scale, scale),
              (context, offset) {
                context.paintChild(child!, offset);
                dmPrint('painted $i/$widgetIndex, a widget in text at $offset');
              },
            );

            child = childParentData.nextSibling;
            widgetIndex++;
          }
        }
      } else {
        assert(false);
      }

      i++;
    }

    /*
    if (!_hasOverflow) {
      defaultPaint(context, offset);
      return;
    }

    // There's no point in drawing the children if we're empty.
    if (size.isEmpty) return;

    if (clipBehavior == Clip.none) {
      _clipRectLayer = null;
      defaultPaint(context, offset);
    } else {
      // We have overflow and the clipBehavior isn't none. Clip it.
      _clipRectLayer = context.pushClipRect(
          needsCompositing, offset, Offset.zero & size, defaultPaint,
          clipBehavior: clipBehavior, oldLayer: _clipRectLayer);
    }

    assert(() {
      // Only set this if it's null to save work.
      final debugOverflowHints = <DiagnosticsNode>[
        ErrorDescription('The edge of the $runtimeType that is overflowing has been '
            'marked in the rendering with a yellow and black striped pattern. This is '
            'usually caused by the contents being too big for the constraints.'),
        ErrorHint('This is considered an error condition because it indicates that there '
            'is content that cannot be seen. If the content is legitimately bigger than '
            'the available space, consider placing the $runtimeType in a scrollable '
            'container, like a ListView.'),
      ];

      // Simulate a child rect that overflows by the right amount. This child
      // rect is never used for drawing, just for determining the overflow
      // location and amount.
      final Rect overflowChildRect;
      overflowChildRect = Rect.fromLTWH(0.0, 0.0, 0.0, size.height + _overflow);
      paintOverflowIndicator(context, offset, Offset.zero & size, overflowChildRect,
          overflowHints: debugOverflowHints);
      return true;
    }());
    */
  }

  // ClipRectLayer? _clipRectLayer;

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _hasOverflow ? Offset.zero & size : null;

  @override
  String toStringShort() {
    var header = super.toStringShort();
    if (_hasOverflow) header += ' OVERFLOWING';
    return header;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<CrossAxisAlignment>('crossAxisAlignment', crossAxisAlignment))
      ..add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
  }
}

extension on RenderBox {
  FloatTag get tag => ((this as RenderMetaData).metaData as FloatTag);
}

/* Old code from `performLayout`:

    ...

    final sizes = _computeSizes(
      layoutChild: ChildLayoutHelper.layoutChild,
      constraints: constraints,
    );

    final allocatedSize = sizes.allocatedSize;
    var actualSize = sizes.mainSize;
    var crossSize = sizes.crossSize;

    // Align items along the main axis.
    size = constraints.constrain(Size(crossSize, actualSize));
    actualSize = size.height;
    crossSize = size.width;
    final actualSizeDelta = actualSize - allocatedSize;
    _overflow = math.max(0.0, -actualSizeDelta);

    // Position elements
    var childMainPosition = 0.0;
    var child = firstChild;
    while (child != null) {
      final childParentData = child.parentData! as FloatColumnParentData;
      final double childCrossPosition;
      switch (_crossAxisAlignment) {
        case CrossAxisAlignment.start:
        case CrossAxisAlignment.end:
          childCrossPosition =
              _crossAxisAlignment == CrossAxisAlignment.start ? 0.0 : crossSize - child.size.width;
          break;
        case CrossAxisAlignment.center:
          childCrossPosition = crossSize / 2.0 - child.size.width / 2.0;
          break;
        case CrossAxisAlignment.stretch:
          childCrossPosition = 0.0;
          break;
        case CrossAxisAlignment.baseline:
          childCrossPosition = 0.0;
          break;
      }
      childParentData.offset = Offset(childCrossPosition, childMainPosition);
      childMainPosition += child.size.height;
      child = childParentData.nextSibling;
    }
  }

  _LayoutSizes _computeSizes({
    required BoxConstraints constraints,
    required ChildLayouter layoutChild,
  }) {
    assert(_debugHasNecessaryDirections);
    assert(constraints != null); // ignore: unnecessary_null_comparison

    var crossSize = 0.0;
    var allocatedSize = 0.0; // Sum of the sizes of the children.
    var child = firstChild;
    while (child != null) {
      final childParentData = child.parentData! as FloatColumnParentData;
      final BoxConstraints innerConstraints;
      if (crossAxisAlignment == CrossAxisAlignment.stretch) {
        innerConstraints = BoxConstraints.tightFor(width: constraints.maxWidth);
      } else {
        innerConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
      }
      final childSize = layoutChild(child, innerConstraints);
      allocatedSize += childSize.height;
      crossSize = math.max(crossSize, childSize.width);
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    final idealSize = allocatedSize;
    return _LayoutSizes(
      mainSize: idealSize,
      crossSize: crossSize,
      allocatedSize: allocatedSize,
    );
  }

// ignore: avoid_private_typedef_functions
typedef _ChildSizingFunction = double Function(RenderBox child, double extent);

class _LayoutSizes {
  const _LayoutSizes({
    required this.mainSize,
    required this.crossSize,
    required this.allocatedSize,
  });

  final double mainSize;
  final double crossSize;
  final double allocatedSize;
}

*/