import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The shared 16-by-16 glyph vocabulary for Regalia's pixel interface.
enum PixelGlyph {
  arrowLeft,
  arrowRight,
  book,
  cup,
  gear,
  shield,
  error,
  check,
  cross,
  undo,
  redo,
  reset,
  checklist,
  hint,
  row,
  column,
  region,
  spacing,
  tap,
  lock,
  crown,
  star,
  challenge,
  ellipsis,
  hourglass,
}

/// A hard-edged, code-native icon drawn on a 16-by-16 logical pixel grid.
///
/// Icons are intentionally offered at 16, 24, and 32 logical pixels. Those
/// sizes keep the shared grid crisp at the device-pixel ratios supported by
/// the app.
class PixelIcon extends StatelessWidget {
  const PixelIcon(
    this.glyph, {
    super.key,
    this.color,
    this.size = 24,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  }) : assert(size == 16 || size == 24 || size == 32);

  final PixelGlyph glyph;
  final Color? color;
  final double size;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _PixelGlyphPainter(
          glyph: glyph,
          color: resolvedColor,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
      ),
    );

    if (excludeFromSemantics || semanticLabel == null) {
      return ExcludeSemantics(child: icon);
    }
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: icon),
    );
  }
}

/// A square pixel icon action with a minimum 48-by-48 interaction target.
///
/// [tooltip] supplies both the hover/long-press tooltip and the accessible
/// button label. The glyph itself is excluded from semantics to avoid a
/// duplicate announcement.
class PixelIconButton extends StatelessWidget {
  const PixelIconButton({
    super.key,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 24,
    this.color,
    this.disabledColor,
    this.style,
    this.focusNode,
    this.autofocus = false,
  }) : assert(tooltip != ''),
       assert(iconSize == 16 || iconSize == 24 || iconSize == 32);

  final PixelGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final double iconSize;
  final Color? color;
  final Color? disabledColor;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;

  static const _pixelStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.square(48)),
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    color: color,
    disabledColor: disabledColor,
    iconSize: iconSize,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    padding: EdgeInsets.zero,
    style: (style ?? const ButtonStyle()).merge(_pixelStyle),
    focusNode: focusNode,
    autofocus: autofocus,
    icon: PixelIcon(glyph, size: iconSize, excludeFromSemantics: true),
  );
}

/// A localized, pixel-art replacement for Flutter's implicit back button.
class PixelBackButton extends StatelessWidget {
  const PixelBackButton({super.key, this.onPressed, this.color, this.style});

  final VoidCallback? onPressed;
  final Color? color;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => PixelIconButton(
    glyph: PixelGlyph.arrowLeft,
    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    onPressed: onPressed ?? () => Navigator.maybePop(context),
    color: color,
    style: style,
  );
}

/// A shared square-cornered surface with a hard, unblurred drop shadow.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.shadowColor,
    this.borderWidth = 2,
    this.shadowOffset = const Offset(4, 4),
  }) : assert(borderWidth >= 0);

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Color? shadowColor;
  final double borderWidth;
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        border: Border.all(
          color: borderColor ?? colors.outline,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor ?? Colors.black.withValues(alpha: .36),
            offset: shadowOffset,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A framed, hard-shadowed dialog that keeps the same pixel surface language
/// as boards, cards, and settings panels.
class PixelDialog extends StatelessWidget {
  const PixelDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.semanticLabel,
    this.maxWidth = 420,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final Widget? icon;
  final String? semanticLabel;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.all(24),
    child: Semantics(
      namesRoute: true,
      scopesRoute: true,
      label: semanticLabel,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: PixelPanel(
          borderColor: Theme.of(context).colorScheme.secondary,
          borderWidth: 3,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(child: icon!),
                const SizedBox(height: 16),
              ],
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                child: title,
              ),
              const SizedBox(height: 12),
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
                child: content,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A keyboard-accessible, instant pixel toggle with a 48-pixel tap target.
class PixelToggle extends StatelessWidget {
  const PixelToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.activeColor,
    this.inactiveColor,
    this.borderColor,
    this.focusNode,
    this.autofocus = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? borderColor;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    void toggle() => onChanged?.call(!value);

    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : toggle,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: 48,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onChanged == null ? null : toggle,
              focusNode: focusNode,
              autofocus: autofocus,
              canRequestFocus: onChanged != null,
              excludeFromSemantics: true,
              splashFactory: NoSplash.splashFactory,
              child: Center(
                child: _PixelToggleVisual(
                  value: value,
                  enabled: onChanged != null,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  borderColor: borderColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text-labelled settings row using the same pixel toggle language.
class PixelToggleTile extends StatelessWidget {
  const PixelToggleTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.activeColor,
    this.inactiveColor,
    this.borderColor,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    void toggle() => onChanged?.call(!value);

    return MergeSemantics(
      child: Semantics(
        toggled: value,
        enabled: onChanged != null,
        onTap: onChanged == null ? null : toggle,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onChanged == null ? null : toggle,
            excludeFromSemantics: true,
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              padding: padding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DefaultTextStyle.merge(
                            style: Theme.of(context).textTheme.titleMedium,
                            child: title,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            DefaultTextStyle.merge(
                              style: Theme.of(context).textTheme.bodyMedium,
                              child: subtitle!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ExcludeSemantics(
                      child: _PixelToggleVisual(
                        value: value,
                        enabled: onChanged != null,
                        activeColor: activeColor,
                        inactiveColor: inactiveColor,
                        borderColor: borderColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PixelToggleVisual extends StatelessWidget {
  const _PixelToggleVisual({
    required this.value,
    required this.enabled,
    required this.activeColor,
    required this.inactiveColor,
    required this.borderColor,
  });

  final bool value;
  final bool enabled;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = activeColor ?? colors.secondary;
    final inactive = inactiveColor ?? colors.surfaceContainerHighest;
    final border = borderColor ?? colors.onSurface;
    final thumb = value ? colors.onSecondary : colors.onSurfaceVariant;
    final glyphColor = value ? active : inactive;

    return Opacity(
      opacity: enabled ? 1 : .48,
      child: Container(
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: value ? active : inactive,
          border: Border.all(color: border, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .32),
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: value ? 20 : 2,
              top: 2,
              child: ColoredBox(
                color: thumb,
                child: PixelIcon(
                  value ? PixelGlyph.check : PixelGlyph.cross,
                  color: glyphColor,
                  size: 16,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A square-segment progress indicator.
///
/// A null [value] renders a repeating three-segment indeterminate pulse. A
/// non-null value fills a discrete number of segments and must be between zero
/// and one. Motion stops automatically when reduced motion is requested.
class PixelProgressBar extends StatefulWidget {
  const PixelProgressBar({
    super.key,
    this.value,
    this.segments = 12,
    this.height = 12,
    this.color,
    this.trackColor,
    this.semanticLabel,
    this.semanticValue,
    this.animationDuration = const Duration(milliseconds: 960),
  }) : assert(value == null || (value >= 0 && value <= 1)),
       assert(segments > 0),
       assert(height > 0);

  final double? value;
  final int segments;
  final double height;
  final Color? color;
  final Color? trackColor;
  final String? semanticLabel;
  final String? semanticValue;
  final Duration animationDuration;

  @override
  State<PixelProgressBar> createState() => _PixelProgressBarState();
}

class _PixelProgressBarState extends State<PixelProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.animationDuration,
  );

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PixelProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _controller.duration = widget.animationDuration;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate = widget.value == null && !_reduceMotion;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = widget.color ?? colors.secondary;
    final background = widget.trackColor ?? colors.surfaceContainerHighest;
    final semanticsValue =
        widget.semanticValue ??
        (widget.value == null ? null : '${(widget.value! * 100).round()}%');

    return Semantics(
      label: widget.semanticLabel,
      value: semanticsValue,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final naturalWidth =
                widget.segments * widget.height + (widget.segments - 1) * 2;
            final width =
                constraints.hasBoundedWidth
                    ? constraints.maxWidth
                    : naturalWidth;
            return SizedBox(
              width: width,
              height: widget.height,
              child: AnimatedBuilder(
                animation: _controller,
                builder:
                    (context, _) => CustomPaint(
                      painter: _PixelProgressPainter(
                        value: widget.value,
                        phase: _controller.isAnimating ? _controller.value : .5,
                        segments: widget.segments,
                        color: foreground,
                        trackColor: background,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(
                          context,
                        ),
                      ),
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PixelGlyphPainter extends CustomPainter {
  const _PixelGlyphPainter({
    required this.glyph,
    required this.color,
    required this.devicePixelRatio,
  });

  final PixelGlyph glyph;
  final Color color;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _PixelGrid(canvas, size, devicePixelRatio);
    final shade = Color.lerp(color, Colors.black, .34)!;
    final deepShade = Color.lerp(color, Colors.black, .56)!;
    final light = Color.lerp(color, Colors.white, .34)!;

    switch (glyph) {
      case PixelGlyph.arrowLeft:
        _arrow(p, color, shade, light, left: true);
      case PixelGlyph.arrowRight:
        _arrow(p, color, shade, light, left: false);
      case PixelGlyph.book:
        _book(p, color, shade, deepShade, light);
      case PixelGlyph.cup:
        _cup(p, color, shade, deepShade, light);
      case PixelGlyph.gear:
        _gear(p, color, shade, deepShade, light);
      case PixelGlyph.shield:
        _shield(p, color, shade, deepShade, light);
      case PixelGlyph.error:
        _error(p, color, shade, deepShade, light);
      case PixelGlyph.check:
        _check(p, color, shade, light);
      case PixelGlyph.cross:
        _cross(p, color, shade, light);
      case PixelGlyph.undo:
        _turn(p, color, shade, light, left: true);
      case PixelGlyph.redo:
        _turn(p, color, shade, light, left: false);
      case PixelGlyph.reset:
        _reset(p, color, shade, light);
      case PixelGlyph.checklist:
        _checklist(p, color, shade, deepShade, light);
      case PixelGlyph.hint:
        _hint(p, color, shade, deepShade, light);
      case PixelGlyph.row:
        _row(p, color, shade, deepShade, light);
      case PixelGlyph.column:
        _column(p, color, shade, deepShade, light);
      case PixelGlyph.region:
        _region(p, color, shade, deepShade, light);
      case PixelGlyph.spacing:
        _spacing(p, color, shade, light);
      case PixelGlyph.tap:
        _tap(p, color, shade, deepShade, light);
      case PixelGlyph.lock:
        _lock(p, color, shade, deepShade, light);
      case PixelGlyph.crown:
        _crown(p, color, shade, deepShade, light);
      case PixelGlyph.star:
        _star(p, color, shade, light);
      case PixelGlyph.challenge:
        _challenge(p, color, shade, deepShade, light);
      case PixelGlyph.ellipsis:
        _ellipsis(p, color, shade, light);
      case PixelGlyph.hourglass:
        _hourglass(p, color, shade, deepShade, light);
    }
  }

  void _arrow(
    _PixelGrid p,
    Color face,
    Color shade,
    Color light, {
    required bool left,
  }) {
    final outline =
        left
            ? const [
              Offset(1, 8),
              Offset(7, 2),
              Offset(10, 2),
              Offset(10, 5),
              Offset(15, 5),
              Offset(15, 11),
              Offset(10, 11),
              Offset(10, 14),
            ]
            : const [
              Offset(15, 8),
              Offset(9, 2),
              Offset(6, 2),
              Offset(6, 5),
              Offset(1, 5),
              Offset(1, 11),
              Offset(6, 11),
              Offset(6, 14),
            ];
    final fill =
        left
            ? const [
              Offset(3, 8),
              Offset(8, 3),
              Offset(9, 3),
              Offset(9, 6),
              Offset(14, 6),
              Offset(14, 10),
              Offset(9, 10),
              Offset(9, 13),
            ]
            : const [
              Offset(13, 8),
              Offset(8, 3),
              Offset(7, 3),
              Offset(7, 6),
              Offset(2, 6),
              Offset(2, 10),
              Offset(7, 10),
              Offset(7, 13),
            ];
    p.polygon(outline, shade);
    p.polygon(fill, face);
    p.rect(left ? 8 : 3, 6, 5, 1, light);
  }

  void _book(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(1, 3, 14, 12, deep);
    p.rect(2, 2, 6, 11, shade);
    p.rect(8, 2, 6, 11, shade);
    p.rect(2, 3, 5, 9, face);
    p.rect(9, 3, 5, 9, face);
    p.rect(7, 3, 2, 11, deep);
    p.rect(3, 4, 3, 1, light);
    p.rect(10, 4, 3, 1, light);
    p.rect(3, 7, 3, 1, shade);
    p.rect(10, 7, 3, 1, shade);
    p.rect(3, 10, 3, 1, shade);
    p.rect(10, 10, 3, 1, shade);
    p.rect(2, 13, 5, 1, face);
    p.rect(9, 13, 5, 1, face);
  }

  void _cup(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(2, 4, 10, 2, deep);
    p.rect(2, 5, 10, 7, shade);
    p.rect(3, 5, 8, 6, face);
    p.rect(4, 6, 2, 4, light);
    p.rect(11, 6, 4, 5, deep);
    p.rect(12, 7, 2, 3, face);
    p.rect(4, 12, 6, 2, shade);
    p.rect(1, 14, 13, 1, deep);
    p.rect(5, 1, 2, 2, light);
    p.rect(9, 0, 2, 3, shade);
  }

  void _gear(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(6, 1, 4, 3, deep);
    p.rect(6, 12, 4, 3, deep);
    p.rect(1, 6, 3, 4, deep);
    p.rect(12, 6, 3, 4, deep);
    p.rect(3, 3, 3, 3, deep);
    p.rect(10, 3, 3, 3, deep);
    p.rect(3, 10, 3, 3, deep);
    p.rect(10, 10, 3, 3, deep);
    p.rect(4, 3, 8, 10, shade);
    p.rect(3, 4, 10, 8, shade);
    p.rect(5, 4, 6, 8, face);
    p.rect(4, 5, 8, 6, face);
    p.rect(6, 6, 4, 4, deep);
    p.rect(7, 7, 2, 2, light);
    p.rect(5, 4, 4, 1, light);
  }

  void _shield(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.polygon(const [
      Offset(2, 2),
      Offset(8, 0),
      Offset(14, 2),
      Offset(14, 8),
      Offset(12, 12),
      Offset(8, 16),
      Offset(4, 12),
      Offset(2, 8),
    ], deep);
    p.polygon(const [
      Offset(3, 3),
      Offset(8, 1),
      Offset(13, 3),
      Offset(13, 8),
      Offset(11, 11),
      Offset(8, 14),
      Offset(5, 11),
      Offset(3, 8),
    ], face);
    p.polygon(const [
      Offset(4, 4),
      Offset(8, 2),
      Offset(8, 12),
      Offset(6, 10),
      Offset(4, 7),
    ], light);
    p.rect(8, 2, 4, 2, shade);
    p.rect(8, 4, 4, 7, shade);
  }

  void _error(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.polygon(const [
      Offset(5, 1),
      Offset(11, 1),
      Offset(15, 5),
      Offset(15, 11),
      Offset(11, 15),
      Offset(5, 15),
      Offset(1, 11),
      Offset(1, 5),
    ], deep);
    p.polygon(const [
      Offset(5, 2),
      Offset(11, 2),
      Offset(14, 5),
      Offset(14, 11),
      Offset(11, 14),
      Offset(5, 14),
      Offset(2, 11),
      Offset(2, 5),
    ], face);
    p.rect(4, 3, 6, 1, light);
    p.rect(7, 4, 3, 6, shade);
    p.rect(7, 11, 3, 3, shade);
    p.rect(8, 4, 1, 5, light);
    p.rect(8, 11, 1, 1, light);
  }

  void _check(_PixelGrid p, Color face, Color shade, Color light) {
    p.polygon(const [
      Offset(1, 8),
      Offset(4, 5),
      Offset(7, 8),
      Offset(12, 2),
      Offset(15, 5),
      Offset(7, 14),
    ], shade);
    p.polygon(const [
      Offset(3, 8),
      Offset(4, 7),
      Offset(7, 10),
      Offset(13, 4),
      Offset(14, 5),
      Offset(7, 12),
    ], face);
    p.rect(4, 8, 2, 1, light);
    p.rect(11, 5, 2, 1, light);
  }

  void _cross(_PixelGrid p, Color face, Color shade, Color light) {
    p.polygon(const [
      Offset(2, 4),
      Offset(4, 2),
      Offset(8, 6),
      Offset(12, 2),
      Offset(14, 4),
      Offset(10, 8),
      Offset(14, 12),
      Offset(12, 14),
      Offset(8, 10),
      Offset(4, 14),
      Offset(2, 12),
      Offset(6, 8),
    ], shade);
    p.polygon(const [
      Offset(3, 4),
      Offset(4, 3),
      Offset(8, 7),
      Offset(12, 3),
      Offset(13, 4),
      Offset(9, 8),
      Offset(13, 12),
      Offset(12, 13),
      Offset(8, 9),
      Offset(4, 13),
      Offset(3, 12),
      Offset(7, 8),
    ], face);
    p.rect(4, 4, 2, 1, light);
  }

  void _turn(
    _PixelGrid p,
    Color face,
    Color shade,
    Color light, {
    required bool left,
  }) {
    if (left) {
      p.polygon(const [
        Offset(1, 7),
        Offset(6, 2),
        Offset(9, 2),
        Offset(9, 5),
        Offset(12, 5),
        Offset(15, 8),
        Offset(15, 13),
        Offset(12, 13),
        Offset(12, 9),
        Offset(11, 8),
        Offset(9, 8),
        Offset(9, 11),
      ], shade);
      p.polygon(const [
        Offset(3, 7),
        Offset(7, 3),
        Offset(8, 3),
        Offset(8, 6),
        Offset(12, 6),
        Offset(14, 8),
        Offset(14, 12),
        Offset(13, 12),
        Offset(13, 9),
        Offset(11, 7),
        Offset(8, 7),
        Offset(8, 10),
      ], face);
      p.rect(8, 6, 4, 1, light);
    } else {
      p.polygon(const [
        Offset(15, 7),
        Offset(10, 2),
        Offset(7, 2),
        Offset(7, 5),
        Offset(4, 5),
        Offset(1, 8),
        Offset(1, 13),
        Offset(4, 13),
        Offset(4, 9),
        Offset(5, 8),
        Offset(7, 8),
        Offset(7, 11),
      ], shade);
      p.polygon(const [
        Offset(13, 7),
        Offset(9, 3),
        Offset(8, 3),
        Offset(8, 6),
        Offset(4, 6),
        Offset(2, 8),
        Offset(2, 12),
        Offset(3, 12),
        Offset(3, 9),
        Offset(5, 7),
        Offset(8, 7),
        Offset(8, 10),
      ], face);
      p.rect(4, 6, 4, 1, light);
    }
  }

  void _reset(_PixelGrid p, Color face, Color shade, Color light) {
    p.rect(4, 2, 7, 3, shade);
    p.rect(2, 4, 3, 8, shade);
    p.rect(4, 11, 8, 3, shade);
    p.rect(11, 7, 3, 5, shade);
    p.polygon(const [
      Offset(9, 1),
      Offset(15, 1),
      Offset(15, 7),
      Offset(12, 4),
    ], shade);
    p.rect(5, 3, 6, 1, face);
    p.rect(3, 5, 1, 6, face);
    p.rect(5, 12, 6, 1, face);
    p.rect(12, 8, 1, 3, face);
    p.polygon(const [
      Offset(10, 2),
      Offset(14, 2),
      Offset(14, 6),
      Offset(12, 4),
    ], face);
    p.rect(5, 3, 4, 1, light);
  }

  void _checklist(
    _PixelGrid p,
    Color face,
    Color shade,
    Color deep,
    Color light,
  ) {
    p.rect(2, 1, 12, 14, deep);
    p.rect(3, 2, 10, 12, face);
    p.rect(5, 0, 6, 3, shade);
    p.rect(6, 1, 4, 1, light);
    for (final y in [5.0, 9.0]) {
      p.rect(4, y, 2, 2, shade);
      p.rect(7, y, 4, 1, shade);
      p.rect(7, y + 1, 3, 1, light);
    }
    p.rect(4, 12, 7, 1, shade);
  }

  void _hint(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.polygon(const [
      Offset(5, 1),
      Offset(11, 1),
      Offset(14, 4),
      Offset(14, 8),
      Offset(11, 11),
      Offset(11, 13),
      Offset(5, 13),
      Offset(5, 11),
      Offset(2, 8),
      Offset(2, 4),
    ], deep);
    p.polygon(const [
      Offset(5, 2),
      Offset(11, 2),
      Offset(13, 4),
      Offset(13, 8),
      Offset(10, 10),
      Offset(10, 12),
      Offset(6, 12),
      Offset(6, 10),
      Offset(3, 8),
      Offset(3, 4),
    ], face);
    p.rect(5, 3, 4, 1, light);
    p.rect(4, 4, 2, 4, light);
    p.rect(6, 10, 4, 2, shade);
    p.rect(5, 13, 6, 2, deep);
    p.rect(6, 13, 4, 1, face);
  }

  void _row(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(1, 2, 14, 12, deep);
    p.rect(2, 3, 12, 3, shade);
    p.rect(2, 7, 12, 3, face);
    p.rect(2, 11, 12, 2, shade);
    p.rect(3, 7, 10, 1, light);
    p.rect(2, 6, 12, 1, deep);
    p.rect(2, 10, 12, 1, deep);
    p.rect(5, 3, 1, 10, deep);
    p.rect(10, 3, 1, 10, deep);
  }

  void _column(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(2, 1, 12, 14, deep);
    p.rect(3, 2, 3, 12, shade);
    p.rect(7, 2, 2, 12, face);
    p.rect(10, 2, 3, 12, shade);
    p.rect(7, 3, 2, 1, light);
    p.rect(6, 2, 1, 12, deep);
    p.rect(9, 2, 1, 12, deep);
    p.rect(3, 5, 10, 1, deep);
    p.rect(3, 10, 10, 1, deep);
  }

  void _region(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(1, 1, 6, 5, deep);
    p.rect(2, 2, 4, 3, face);
    p.rect(8, 1, 7, 8, deep);
    p.rect(9, 2, 5, 6, shade);
    p.rect(1, 7, 8, 8, deep);
    p.rect(2, 8, 6, 6, shade);
    p.rect(10, 10, 5, 5, deep);
    p.rect(11, 11, 3, 3, face);
    p.rect(2, 2, 3, 1, light);
    p.rect(9, 2, 3, 1, light);
    p.rect(2, 8, 3, 1, light);
    p.rect(11, 11, 2, 1, light);
  }

  void _spacing(_PixelGrid p, Color face, Color shade, Color light) {
    p.rect(7, 6, 2, 4, shade);
    p.rect(6, 7, 4, 2, shade);
    p.polygon(const [
      Offset(1, 4),
      Offset(5, 1),
      Offset(5, 3),
      Offset(7, 3),
      Offset(7, 6),
      Offset(4, 6),
      Offset(4, 5),
    ], shade);
    p.polygon(const [
      Offset(15, 4),
      Offset(11, 1),
      Offset(11, 3),
      Offset(9, 3),
      Offset(9, 6),
      Offset(12, 6),
      Offset(12, 5),
    ], shade);
    p.polygon(const [
      Offset(1, 12),
      Offset(5, 15),
      Offset(5, 13),
      Offset(7, 13),
      Offset(7, 10),
      Offset(4, 10),
      Offset(4, 11),
    ], shade);
    p.polygon(const [
      Offset(15, 12),
      Offset(11, 15),
      Offset(11, 13),
      Offset(9, 13),
      Offset(9, 10),
      Offset(12, 10),
      Offset(12, 11),
    ], shade);
    p.rect(4, 3, 3, 2, face);
    p.rect(9, 3, 3, 2, face);
    p.rect(4, 11, 3, 2, face);
    p.rect(9, 11, 3, 2, face);
    p.rect(5, 3, 1, 1, light);
    p.rect(10, 3, 1, 1, light);
  }

  void _tap(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(7, 1, 3, 9, deep);
    p.rect(8, 2, 1, 7, light);
    p.rect(4, 7, 3, 5, deep);
    p.rect(10, 6, 3, 6, deep);
    p.rect(13, 8, 2, 5, deep);
    p.polygon(const [
      Offset(4, 9),
      Offset(6, 8),
      Offset(8, 10),
      Offset(8, 7),
      Offset(10, 7),
      Offset(11, 9),
      Offset(12, 8),
      Offset(14, 9),
      Offset(14, 13),
      Offset(12, 15),
      Offset(7, 15),
      Offset(4, 12),
    ], shade);
    p.polygon(const [
      Offset(5, 9),
      Offset(6, 9),
      Offset(9, 12),
      Offset(9, 8),
      Offset(10, 8),
      Offset(11, 11),
      Offset(12, 9),
      Offset(13, 10),
      Offset(13, 13),
      Offset(11, 14),
      Offset(7, 14),
      Offset(5, 12),
    ], face);
    p.rect(8, 2, 1, 5, light);
  }

  void _lock(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.rect(4, 2, 8, 2, deep);
    p.rect(3, 4, 3, 5, deep);
    p.rect(10, 4, 3, 5, deep);
    p.rect(5, 3, 6, 2, face);
    p.rect(4, 7, 8, 2, face);
    p.rect(2, 7, 12, 8, deep);
    p.rect(3, 8, 10, 6, face);
    p.rect(4, 8, 8, 1, light);
    p.rect(7, 10, 2, 4, shade);
  }

  void _crown(_PixelGrid p, Color face, Color shade, Color deep, Color light) {
    p.polygon(const [
      Offset(1, 5),
      Offset(4, 8),
      Offset(5, 2),
      Offset(8, 7),
      Offset(11, 2),
      Offset(12, 8),
      Offset(15, 5),
      Offset(14, 14),
      Offset(2, 14),
    ], deep);
    p.polygon(const [
      Offset(2, 7),
      Offset(5, 9),
      Offset(6, 5),
      Offset(8, 9),
      Offset(10, 5),
      Offset(11, 9),
      Offset(14, 7),
      Offset(13, 12),
      Offset(3, 12),
    ], face);
    p.rect(2, 11, 12, 4, deep);
    p.rect(3, 11, 10, 3, face);
    p.rect(4, 11, 8, 1, light);
    p.rect(4, 14, 8, 1, shade);
  }

  void _star(_PixelGrid p, Color face, Color shade, Color light) {
    p.polygon(const [
      Offset(8, 0),
      Offset(10, 5),
      Offset(16, 6),
      Offset(11, 9),
      Offset(13, 15),
      Offset(8, 11),
      Offset(3, 15),
      Offset(5, 9),
      Offset(0, 6),
      Offset(6, 5),
    ], shade);
    p.polygon(const [
      Offset(8, 2),
      Offset(9, 6),
      Offset(13, 7),
      Offset(10, 9),
      Offset(11, 12),
      Offset(8, 10),
      Offset(5, 12),
      Offset(6, 9),
      Offset(3, 7),
      Offset(7, 6),
    ], face);
    p.rect(7, 4, 2, 4, light);
    p.rect(5, 6, 4, 2, light);
  }

  void _challenge(
    _PixelGrid p,
    Color face,
    Color shade,
    Color deep,
    Color light,
  ) {
    p.polygon(const [
      Offset(2, 1),
      Offset(7, 6),
      Offset(5, 8),
      Offset(0, 3),
      Offset(0, 1),
    ], deep);
    p.polygon(const [
      Offset(14, 1),
      Offset(9, 6),
      Offset(11, 8),
      Offset(16, 3),
      Offset(16, 1),
    ], deep);
    p.rect(5, 7, 3, 6, shade);
    p.rect(8, 7, 3, 6, shade);
    p.polygon(const [
      Offset(3, 12),
      Offset(7, 12),
      Offset(7, 15),
      Offset(5, 14),
      Offset(3, 15),
    ], deep);
    p.polygon(const [
      Offset(13, 12),
      Offset(9, 12),
      Offset(9, 15),
      Offset(11, 14),
      Offset(13, 15),
    ], deep);
    p.polygon(const [
      Offset(2, 2),
      Offset(7, 7),
      Offset(6, 8),
      Offset(1, 3),
    ], face);
    p.polygon(const [
      Offset(14, 2),
      Offset(9, 7),
      Offset(10, 8),
      Offset(15, 3),
    ], face);
    p.rect(6, 8, 1, 4, light);
    p.rect(9, 8, 1, 4, light);
    p.rect(6, 6, 4, 4, deep);
    p.rect(7, 7, 2, 2, light);
  }

  void _ellipsis(_PixelGrid p, Color face, Color shade, Color light) {
    for (final x in [1.0, 6.0, 11.0]) {
      p.rect(x, 6, 4, 5, shade);
      p.rect(x + 1, 6, 3, 4, face);
      p.rect(x + 1, 6, 2, 1, light);
    }
  }

  void _hourglass(
    _PixelGrid p,
    Color face,
    Color shade,
    Color deep,
    Color light,
  ) {
    p.rect(2, 1, 12, 3, deep);
    p.rect(2, 12, 12, 3, deep);
    p.rect(4, 3, 8, 2, shade);
    p.rect(5, 5, 6, 2, shade);
    p.rect(7, 7, 2, 2, deep);
    p.rect(5, 9, 6, 2, shade);
    p.rect(4, 11, 8, 2, shade);
    p.rect(3, 2, 10, 1, face);
    p.rect(3, 13, 10, 1, face);
    p.rect(5, 4, 6, 1, light);
    p.rect(6, 5, 4, 1, face);
    p.rect(7, 6, 2, 2, face);
    p.rect(6, 10, 4, 1, face);
    p.rect(5, 11, 6, 1, light);
  }

  @override
  bool shouldRepaint(_PixelGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.color != color ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}

class _PixelGrid {
  const _PixelGrid(this.canvas, this.size, this.devicePixelRatio);

  final Canvas canvas;
  final Size size;
  final double devicePixelRatio;

  double get _unit => math.min(size.width, size.height) / 16;
  double get _originX => (size.width - _unit * 16) / 2;
  double get _originY => (size.height - _unit * 16) / 2;

  double _snap(double value) =>
      (value * devicePixelRatio).roundToDouble() / devicePixelRatio;

  Offset _point(Offset point) => Offset(
    _snap(_originX + point.dx * _unit),
    _snap(_originY + point.dy * _unit),
  );

  void rect(double x, double y, double width, double height, Color color) {
    final left = _snap(_originX + x * _unit);
    final top = _snap(_originY + y * _unit);
    final right = _snap(_originX + (x + width) * _unit);
    final bottom = _snap(_originY + (y + height) * _unit);
    canvas.drawRect(
      Rect.fromLTRB(left, top, right, bottom),
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }

  void polygon(List<Offset> points, Color color) {
    if (points.isEmpty) return;
    final first = _point(points.first);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final snapped = _point(point);
      path.lineTo(snapped.dx, snapped.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = false,
    );
  }
}

class _PixelProgressPainter extends CustomPainter {
  const _PixelProgressPainter({
    required this.value,
    required this.phase,
    required this.segments,
    required this.color,
    required this.trackColor,
    required this.devicePixelRatio,
  });

  final double? value;
  final double phase;
  final int segments;
  final Color color;
  final Color trackColor;
  final double devicePixelRatio;

  double _snap(double value) =>
      (value * devicePixelRatio).roundToDouble() / devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = _snap(math.max(1, size.height / 6));
    final segmentWidth = (size.width - gap * (segments - 1)) / segments;
    final filled = value == null ? 0 : (value! * segments).ceil();
    final head = (phase * segments).floor() % segments;
    final trackPaint =
        Paint()
          ..color = trackColor
          ..isAntiAlias = false;

    for (var index = 0; index < segments; index++) {
      final left = _snap(index * (segmentWidth + gap));
      final right = _snap(left + segmentWidth);
      final rect = Rect.fromLTRB(left, 0, right, size.height);
      canvas.drawRect(rect, trackPaint);

      Color? active;
      if (value != null && index < filled) {
        active = color;
      } else if (value == null) {
        final distance = (head - index + segments) % segments;
        active = switch (distance) {
          0 => color,
          1 => color.withValues(alpha: .68),
          2 => color.withValues(alpha: .36),
          _ => null,
        };
      }
      if (active != null) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = active
            ..isAntiAlias = false,
        );
        final highlightHeight = _snap(math.max(1, size.height / 6));
        canvas.drawRect(
          Rect.fromLTRB(left, 0, right, highlightHeight),
          Paint()
            ..color = Color.lerp(active, Colors.white, .24)!
            ..isAntiAlias = false,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelProgressPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.phase != phase ||
      oldDelegate.segments != segments ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
