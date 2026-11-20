import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Scrolls its child into view when it becomes [active], moving the list only
/// as far as needed. Arrow keys move the selection off-screen otherwise, and
/// `Scrollable.ensureVisible`'s default recentres the row even when it is
/// already visible, which jumps the list under a mouse click.
class KeepVisible extends StatefulWidget {
  const KeepVisible({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<KeepVisible> createState() => _KeepVisibleState();
}

class _KeepVisibleState extends State<KeepVisible> {
  @override
  void initState() {
    super.initState();
    if (widget.active) _schedule();
  }

  @override
  void didUpdateWidget(KeepVisible oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final object = context.findRenderObject();
      final scrollable = Scrollable.maybeOf(context);
      if (object == null || scrollable == null) return;
      final viewport = RenderAbstractViewport.maybeOf(object);
      if (viewport == null) return;
      final position = scrollable.position;
      // Offsets that put the row at the top (0.0) or bottom (1.0) edge.
      final top = viewport.getOffsetToReveal(object, 0.0).offset;
      final bottom = viewport.getOffsetToReveal(object, 1.0).offset;
      final double target;
      if (position.pixels > top) {
        target = top;
      } else if (position.pixels < bottom) {
        target = bottom;
      } else {
        return;
      }
      position.animateTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
