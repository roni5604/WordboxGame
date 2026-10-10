import 'package:flutter/material.dart';

import 'pressable.dart';

/// ערכות צבע מוכנות לכפתורי "ממתק" - כל אחת עם פנים בהיר, תחתית כהה
/// (ה"שפה" התלת-ממדית) וצבע טקסט.
class CandyPalette {
  final Color top;
  final Color bottom;
  final Color lip;
  final Color text;

  const CandyPalette({required this.top, required this.bottom, required this.lip, this.text = Colors.white});

  static const green = CandyPalette(top: Color(0xFF7CEB6E), bottom: Color(0xFF33C24D), lip: Color(0xFF1E8F37));
  static const orange = CandyPalette(top: Color(0xFFFFB259), bottom: Color(0xFFFF7A45), lip: Color(0xFFC94A1C));
  static const purple = CandyPalette(top: Color(0xFFB57BFF), bottom: Color(0xFF7B3FF2), lip: Color(0xFF4F1FB0));
  static const blue = CandyPalette(top: Color(0xFF6FD3FF), bottom: Color(0xFF2E8BFF), lip: Color(0xFF1A5BC4));
  static const pink = CandyPalette(top: Color(0xFFFF8FC0), bottom: Color(0xFFFF4F8B), lip: Color(0xFFC22A62));
  static const gold = CandyPalette(top: Color(0xFFFFE27A), bottom: Color(0xFFFFB700), lip: Color(0xFFC77F00), text: Color(0xFF5A3300));
  static const red = CandyPalette(top: Color(0xFFFF8A80), bottom: Color(0xFFF2463D), lip: Color(0xFFB0221B));
  static const white = CandyPalette(
    top: Color(0xFFFFFFFF),
    bottom: Color(0xFFF1ECFF),
    lip: Color(0xFFC9BFE6),
    text: Color(0xFF4A2F8F),
  );
}

/// כפתור ראשי בסגנון משחקי מובייל מובילים: פנים מבריקות עם גרדיאנט, "שפה"
/// תחתונה כהה שנותנת עומק, והכפתור "שוקע" פיזית כשלוחצים עליו.
class CandyButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final VoidCallback? onPressed;
  final CandyPalette palette;
  final double height;
  final double fontSize;
  final bool loading;
  final bool expand;
  final double radius;

  /// תג קטן בפינה (למשל מספר בקשות חברות ממתינות).
  final int? badgeCount;

  const CandyButton({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.leading,
    this.onPressed,
    this.palette = CandyPalette.green,
    this.height = 60,
    this.fontSize = 20,
    this.loading = false,
    this.expand = true,
    this.radius = 22,
    this.badgeCount,
  });

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (!_enabled && value) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final lipHeight = widget.height * 0.09 + 2;
    final depth = _pressed ? lipHeight * 0.25 : lipHeight;

    final content = widget.loading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3, color: p.text),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 10)],
              if (widget.icon != null) ...[
                Icon(widget.icon, color: p.text, size: widget.fontSize * 1.35, shadows: _textShadows(p)),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        shadows: _textShadows(p),
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.text.withValues(alpha: 0.88),
                          fontSize: widget.fontSize * 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );

    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled
          ? () {
              PressFeedback.trigger();
              widget.onPressed!();
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _enabled || widget.loading ? 1 : 0.5,
        child: SizedBox(
          height: widget.height + lipHeight,
          child: Stack(
            children: [
              // ה"שפה" התחתונה - הצד הכהה שנותן לכפתור עומק.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.lip,
                    borderRadius: BorderRadius.circular(widget.radius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _pressed ? 0.12 : 0.22),
                        blurRadius: _pressed ? 4 : 10,
                        offset: Offset(0, _pressed ? 2 : 5),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: lipHeight - depth,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [p.top, p.bottom],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      // ברק עליון - "זכוכית" מבריקה כמו בכפתורי ממתקים.
                      Positioned(
                        left: widget.radius * 0.5,
                        right: widget.radius * 0.5,
                        top: 3,
                        height: widget.height * 0.38,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.radius),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: content,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final sized = widget.expand ? SizedBox(width: double.infinity, child: button) : button;
    final badge = widget.badgeCount;
    if (badge == null || badge <= 0) return sized;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        sized,
        PositionedDirectional(
          top: -6,
          end: -4,
          child: CountBadge(count: badge),
        ),
      ],
    );
  }

  List<Shadow> _textShadows(CandyPalette p) => p.text == Colors.white
      ? [Shadow(color: p.lip.withValues(alpha: 0.9), offset: const Offset(0, 2), blurRadius: 0)]
      : const [];
}

/// תג אדום עגול עם מספר - כמו התראות במשחקים (בקשות חברות, הזמנות).
class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFF3B47),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
        ),
      ),
    );
  }
}

/// כפתור עגול קטן (חזרה, הגדרות, סגירה) באותה שפה עיצובית.
class CandyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final CandyPalette palette;
  final double size;
  final String? tooltip;
  final int? badgeCount;

  const CandyIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.palette = CandyPalette.white,
    this.size = 44,
    this.tooltip,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final circle = Pressable(
      onTap: onPressed,
      semanticLabel: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.top, palette.bottom],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          boxShadow: [
            BoxShadow(color: palette.lip, offset: const Offset(0, 3)),
            const BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: palette.text, size: size * 0.52),
      ),
    );
    final withTooltip = tooltip == null ? circle : Tooltip(message: tooltip!, child: circle);
    if (badgeCount == null || badgeCount! <= 0) return withTooltip;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        withTooltip,
        PositionedDirectional(top: -6, end: -6, child: CountBadge(count: badgeCount!)),
      ],
    );
  }
}

/// אריח-כפתור גבוה (אייקון גדול מעל טקסט) - לבחירת מצב משחק במסך הבית,
/// כמו האריחים של Clash Royale / Candy Crush. אותה שפה תלת-ממדית כמו
/// [CandyButton], כולל "שקיעה" בלחיצה.
class CandyTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final CandyPalette palette;
  final VoidCallback? onPressed;
  final double height;
  final int? badgeCount;
  final Widget? footer;

  const CandyTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.palette = CandyPalette.blue,
    this.onPressed,
    this.height = 132,
    this.badgeCount,
    this.footer,
  });

  @override
  State<CandyTile> createState() => _CandyTileState();
}

class _CandyTileState extends State<CandyTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    const lip = 7.0;
    final depth = _pressed ? 2.0 : lip;
    final enabled = widget.onPressed != null;

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              PressFeedback.trigger();
              widget.onPressed!();
            }
          : null,
      child: SizedBox(
        height: widget.height + lip,
        child: Stack(
          children: [
            Positioned.fill(
              top: lip,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.lip,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              left: 0,
              right: 0,
              top: lip - depth,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [p.top, p.bottom],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      left: 14,
                      right: 14,
                      height: widget.height * 0.33,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.25),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                            ),
                            child: Icon(widget.icon, color: p.text, size: 30),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                color: p.text,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                shadows: p.text == Colors.white
                                    ? [Shadow(color: p.lip, offset: const Offset(0, 2))]
                                    : null,
                              ),
                            ),
                          ),
                          if (widget.subtitle != null)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  color: p.text.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          if (widget.footer != null) ...[const SizedBox(height: 4), widget.footer!],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final badge = widget.badgeCount;
    if (badge == null || badge <= 0) return tile;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        PositionedDirectional(top: -4, end: -2, child: CountBadge(count: badge)),
      ],
    );
  }
}
