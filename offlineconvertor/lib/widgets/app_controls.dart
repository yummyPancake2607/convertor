import 'package:flutter/material.dart';

import '../core/extensions/context_extensions.dart';
import '../core/theme/app_spacing.dart';
import 'option_sheet.dart';

/// Icon button with a guaranteed 48dp tap target.
///
/// The visible glyph stays small; the touch area around it does not, which is
/// the difference between a row of actions that works on a phone and one that
/// does not.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.size = AppSizes.touchTarget,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Color resolved = enabled
        ? (color ?? context.palette.textSecondary)
        : context.palette.textTertiary.withValues(alpha: 0.4);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: resolved),
        ),
      ),
    );
  }
}

/// Horizontally scrollable filter chips.
///
/// Scrollable rather than an even split: five status filters cannot share a
/// phone's width legibly, and truncating labels is worse than scrolling.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
    this.countBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelBuilder;
  final int? Function(T)? countBuilder;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: <Widget>[
          for (final T value in values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _FilterChip(
                label: labelBuilder(value),
                count: countBuilder?.call(value),
                selected: value == selected,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final Color fg =
        selected ? context.palette.accent : context.palette.textSecondary;

    return Material(
      color: selected ? context.palette.accentSubtle : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? context.palette.accent.withValues(alpha: 0.45)
                  : context.palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: context.text.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null && count! > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.sm - 2),
                Text(
                  '$count',
                  style: context.text.labelMedium?.copyWith(
                    color: selected
                        ? context.palette.accent
                        : context.palette.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field bound to an externally-owned string.
///
/// The controller lives with the widget rather than being rebuilt from [value]
/// on every frame: constructing it in `build` leaks a controller per frame and
/// resets the caret while the user is typing. [value] is only pushed into the
/// field when it changes from the outside (a "clear filters" action, say).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction ?? TextInputAction.done,
      style: context.text.bodyLarge,
      decoration: widget.decoration,
      onChanged: widget.onChanged,
    );
  }
}

/// Full-width search field for a page toolbar.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hintText = 'Search',
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      value: value,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: context.palette.textTertiary,
        ),
        suffixIcon: value.isEmpty
            ? null
            : IconAction(
                icon: Icons.close_rounded,
                tooltip: 'Clear',
                size: 40,
                iconSize: 18,
                onPressed: () => onChanged(''),
              ),
      ),
    );
  }
}

/// A value picker that opens a bottom sheet.
///
/// Used everywhere a desktop build would use a dropdown. Shows the current value
/// with an optional leading widget, and hands option rendering to
/// [showSimpleOptionSheet].
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
    this.sheetTitle = 'Choose',
    this.descriptionBuilder,
    this.leadingBuilder,
    this.placeholder = 'Choose',
    this.enabled = true,
    this.sheetSubtitle,
    this.dense = false,
  });

  final T? value;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String? Function(T)? descriptionBuilder;
  final Widget Function(T)? leadingBuilder;
  final ValueChanged<T> onChanged;
  final String sheetTitle;
  final String? sheetSubtitle;
  final String placeholder;
  final bool enabled;
  final bool dense;

  Future<void> _open(BuildContext context) async {
    final T? chosen = await showSimpleOptionSheet<T>(
      context,
      title: sheetTitle,
      subtitle: sheetSubtitle,
      selected: value,
      options: items
          .map(
            (T item) => SheetOption<T>(
              value: item,
              label: labelBuilder(item),
              description: descriptionBuilder?.call(item),
              leading: leadingBuilder?.call(item),
            ),
          )
          .toList(),
    );
    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final bool usable = enabled && items.isNotEmpty;
    final T? current = value;

    return Material(
      color: context.palette.surfaceSunken,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: usable ? () => _open(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: BoxConstraints(
            minHeight: dense ? AppSizes.controlHeightSmall : AppSizes.controlHeight,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: <Widget>[
              if (current != null && leadingBuilder != null) ...<Widget>[
                leadingBuilder!(current),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  current == null ? placeholder : labelBuilder(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyLarge?.copyWith(
                    color: usable
                        ? context.palette.textPrimary
                        : context.palette.textTertiary,
                  ),
                ),
              ),
              Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: context.palette.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Label + control, stacked on phones and side by side on wider screens.
class LabeledControl extends StatelessWidget {
  const LabeledControl({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.labelWidth = 160,
    this.stacked = true,
  });

  final String label;
  final Widget child;
  final String? hint;
  final double labelWidth;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final Widget labelWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: context.text.labelLarge),
        if (hint != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(hint!, style: context.text.bodySmall),
        ],
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          labelWidget,
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(width: labelWidth, child: labelWidget),
        const SizedBox(width: AppSpacing.lg),
        Expanded(child: child),
      ],
    );
  }
}
