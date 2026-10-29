import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.svg,
    this.isPassword = false,
    this.error,
    this.maxLength,
    this.maxLines,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.counter = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final String? svg;
  final bool isPassword;
  final String? error;
  final int? maxLength;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool counter;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      maxLines: widget.isPassword ? 1 : (widget.maxLines ?? 1),
      maxLength: widget.maxLength,
      obscureText: _hidden && widget.isPassword,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: const TextStyle(color: AppColors.text, fontSize: 14.8),
      decoration: InputDecoration(
        errorText: widget.error,
        errorMaxLines: 3,
        counterText: widget.counter ? null : '',
        hintText: widget.hint,
        hintStyle: const TextStyle(color: AppColors.lightText, fontSize: 14.8),
        prefixIcon: widget.svg == null
            ? null
            : UnconstrainedBox(
                child: SvgPicture.asset(
                  'assets/icons/${widget.svg}.svg',
                  colorFilter: const ColorFilter.mode(AppColors.text, BlendMode.srcIn),
                ),
              ),
        suffixIcon: !widget.isPassword
            ? null
            : IconButton(
                tooltip: _hidden ? '비밀번호 보기' : '비밀번호 숨기기',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: SvgPicture.asset(
                  'assets/icons/visibility${_hidden ? '' : '-off'}.svg',
                  colorFilter: const ColorFilter.mode(AppColors.text, BlendMode.srcIn),
                ),
              ),
      ),
    );
  }
}

/// 필수 입력 표시가 있는 필드 제목.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = true});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(text, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500)),
          if (required) ...[
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}
