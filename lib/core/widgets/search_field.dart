import 'dart:async';
import 'package:flutter/material.dart';
import '../strings.dart';
import '../theme/app_colors.dart';

/// Desktop search field with built-in 250ms debounce, clear button,
/// and >= 44px minimum height.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.hintText = AppStrings.searchHint,
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.focusNode,
    this.debounceDuration = const Duration(milliseconds: 250),
    this.maxWidth = 420,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Duration debounceDuration;
  final double maxWidth;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _showClear = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final bool hasText = _controller.text.isNotEmpty;
    if (_showClear != hasText) {
      setState(() {
        _showClear = hasText;
      });
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        widget.onChanged?.call(_controller.text.trim());
      }
    });
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.maxWidth, minHeight: 44),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: widget.onSubmitted,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.onSurfaceVariant),
            suffixIcon: _showClear
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: AppStrings.clearSearch,
                    splashRadius: 18,
                    onPressed: _clear,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }
}
