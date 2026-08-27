import 'package:flutter/material.dart';

import '../core/extensions/context_extensions.dart';
import '../core/theme/app_spacing.dart';

/// One choice in an [showOptionSheet] list.
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    this.description,
    this.leading,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final Widget? leading;
  final bool enabled;
}

/// A group of options with a heading, for sheets that mix categories.
class SheetGroup<T> {
  const SheetGroup({required this.title, required this.options, this.icon});

  final String title;
  final IconData? icon;
  final List<SheetOption<T>> options;
}

/// Presents a choice as a modal bottom sheet.
///
/// This replaces the dropdown menus a desktop build would use. On a phone a
/// sheet is easier to hit, can show a description per option, and scrolls
/// naturally when there are thirty formats to choose from.
///
/// Returns the chosen value, or null when dismissed.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetGroup<T>> groups,
  T? selected,
  String? subtitle,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) {
      return _OptionSheet<T>(
        title: title,
        subtitle: subtitle,
        groups: groups,
        selected: selected,
      );
    },
  );
}

/// Convenience wrapper for a single ungrouped list of options.
Future<T?> showSimpleOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
  T? selected,
  String? subtitle,
}) {
  return showOptionSheet<T>(
    context,
    title: title,
    subtitle: subtitle,
    selected: selected,
    groups: <SheetGroup<T>>[
      SheetGroup<T>(title: '', options: options),
    ],
  );
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.groups,
    required this.selected,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SheetGroup<T>> groups;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    // Capped so the sheet never covers the whole screen: keeping the page
    // partly visible is what makes a sheet feel dismissible.
    final double maxHeight = context.screenSize.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xs,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: context.text.headlineSmall),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              padding: EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.lg + context.bottomInset,
              ),
              shrinkWrap: true,
              children: <Widget>[
                for (final SheetGroup<T> group in groups) ...<Widget>[
                  if (group.title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl,
                        AppSpacing.md,
                        AppSpacing.xl,
                        AppSpacing.xs,
                      ),
                      child: Row(
                        children: <Widget>[
                          if (group.icon != null) ...<Widget>[
                            Icon(
                              group.icon,
                              size: 13,
                              color: context.palette.textTertiary,
                            ),
                            const SizedBox(width: AppSpacing.sm - 2),
                          ],
                          Text(
                            group.title.toUpperCase(),
                            style: context.text.labelSmall?.copyWith(
                              color: context.palette.textTertiary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final SheetOption<T> option in group.options)
                    _OptionRow<T>(
                      option: option,
                      selected: option.value == selected,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, required this.selected});

  final SheetOption<T> option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: option.enabled
          ? () => Navigator.of(context).pop(option.value)
          : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.touchTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        color: selected ? context.palette.accentSubtle : null,
        child: Row(
          children: <Widget>[
            if (option.leading != null) ...<Widget>[
              option.leading!,
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    option.label,
                    style: context.text.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: option.enabled
                          ? context.palette.textPrimary
                          : context.palette.textTertiary,
                    ),
                  ),
                  if (option.description != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      option.description!,
                      style: context.text.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (selected) ...<Widget>[
              const SizedBox(width: AppSpacing.md),
              Icon(
                Icons.check_rounded,
                size: 20,
                color: context.palette.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
