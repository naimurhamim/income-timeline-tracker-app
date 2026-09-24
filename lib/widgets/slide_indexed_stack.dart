import 'package:flutter/material.dart';

class SlideIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const SlideIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  State<SlideIndexedStack> createState() => _SlideIndexedStackState();
}

class _SlideIndexedStackState extends State<SlideIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _currentIndex;
  late int _previousIndex;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _previousIndex = widget.index;
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isAnimating = false;
            _previousIndex = _currentIndex;
          });
        }
      });
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(SlideIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _previousIndex = _currentIndex;
      _currentIndex = widget.index;
      _isAnimating = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (index) {
        final child = widget.children[index];
        final isCurrent = index == _currentIndex;
        final isPrevious = index == _previousIndex;

        // Using Offstage ensures the state of all children is kept alive
        // (unlike SizedBox.shrink() which would unmount inactive children)
        if (!isCurrent && !isPrevious) {
          return Offstage(
            offstage: true,
            child: child,
          );
        }

        if (!_isAnimating) {
          return Offstage(
            offstage: !isCurrent,
            child: child,
          );
        }

        final slideLeft = _currentIndex > _previousIndex;

        if (isCurrent) {
          final beginOffset = slideLeft ? const Offset(1, 0) : const Offset(-1, 0);
          final animation = Tween<Offset>(
            begin: beginOffset,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
          ));

          return SlideTransition(
            position: animation,
            child: child,
          );
        } else if (isPrevious) {
          final endOffset = slideLeft ? const Offset(-1, 0) : const Offset(1, 0);
          final animation = Tween<Offset>(
            begin: Offset.zero,
            end: endOffset,
          ).animate(CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
          ));

          return SlideTransition(
            position: animation,
            child: child,
          );
        }

        return Offstage(offstage: true, child: child);
      }),
    );
  }
}
