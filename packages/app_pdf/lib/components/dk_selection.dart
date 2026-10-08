import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../theme/haptics.dart';
import 'dk_bottom_bars.dart';
import 'dk_top_bar.dart';

/// Which items are selected, and whether selection mode is on (DK-0222; UI
/// spec §12.1). The mode starts with a first item and ends with Cancel,
/// back or an action; deselecting the last item keeps it on ("0 selected"),
/// as in the platforms' own file apps.
class DkSelection<T> extends ChangeNotifier {
  final _selected = <T>{};
  var _active = false;

  bool get active => _active;
  Set<T> get selected => Set.unmodifiable(_selected);
  bool isSelected(T item) => _selected.contains(item);

  /// Turns selection mode on with [item] selected.
  void start(T item) {
    _active = true;
    _selected.add(item);
    notifyListeners();
  }

  void toggle(T item) {
    if (!_selected.remove(item)) _selected.add(item);
    notifyListeners();
  }

  void selectAll(Iterable<T> items) {
    _selected.addAll(items);
    notifyListeners();
  }

  /// Ends selection mode (Cancel, back, or after an action).
  void exit() {
    if (!_active) return;
    _active = false;
    _selected.clear();
    notifyListeners();
  }
}

/// What [DkSelectable.builder] gets: whether selection mode is on, whether
/// this item is selected, and what a tap and a long press do now. The item
/// (DkFileCard, a page thumbnail) draws its check and tint from the first
/// two and hands the callbacks to its own tappable.
typedef DkSelectState = ({
  bool selecting,
  bool selected,
  VoidCallback onTap,
  VoidCallback onLongPress,
});

/// One item that takes part in selection mode: a long press starts it with
/// this item; while it is on, a tap toggles the item, otherwise a tap opens
/// it ([onOpen]). Each change ticks (`haptics.selected`). Screen readers
/// hear the selected state while selecting, and get a "Select" action
/// instead of the long press.
class DkSelectable<T> extends ConsumerWidget {
  const DkSelectable({
    super.key,
    required this.selection,
    required this.item,
    required this.onOpen,
    required this.builder,
  });

  final DkSelection<T> selection;
  final T item;
  final VoidCallback onOpen;
  final Widget Function(BuildContext context, DkSelectState state) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haptics = ref.read(hapticsProvider);
    final l = AppLocalizations.of(context);
    void start() {
      selection.start(item);
      haptics.selected();
    }

    void toggle() {
      selection.toggle(item);
      haptics.selected();
    }

    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final selecting = selection.active;
        final selected = selection.isSelected(item);
        return Semantics(
          selected: selecting ? selected : null,
          customSemanticsActions: selecting
              ? null
              : {CustomSemanticsAction(label: l.common_select): start},
          child: builder(context, (
            selecting: selecting,
            selected: selected,
            onTap: selecting ? toggle : onOpen,
            onLongPress: selecting ? toggle : start,
          )),
        );
      },
    );
  }
}

/// A screen's frame for selection mode: its own [appBar] normally; while
/// selecting, "3 selected" with Cancel and Select all on top and a
/// DkSelectionBar with [actions] at the bottom, where the shell's tab bar
/// was (it hides while a [DkShellChrome] is above). Back ends selection
/// mode first.
class DkSelectionScaffold<T> extends StatefulWidget {
  const DkSelectionScaffold({
    super.key,
    required this.selection,
    required this.all,
    required this.appBar,
    required this.actions,
    required this.body,
  });

  final DkSelection<T> selection;

  /// Every item on screen, for Select all.
  final Iterable<T> Function() all;
  final PreferredSizeWidget appBar;

  /// The selection bar's actions for what is selected.
  final List<DkBarAction> Function(Set<T> selected) actions;
  final Widget body;

  @override
  State<DkSelectionScaffold<T>> createState() => _DkSelectionScaffoldState<T>();
}

class _DkSelectionScaffoldState<T> extends State<DkSelectionScaffold<T>> {
  ValueNotifier<bool>? _shell;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shell = DkShellChrome.maybeOf(context);
  }

  @override
  void didUpdateWidget(DkSelectionScaffold<T> old) {
    super.didUpdateWidget(old);
    if (old.selection != widget.selection) {
      old.selection.removeListener(_sync);
      widget.selection.addListener(_sync);
    }
  }

  void _sync() => _shell?.value = widget.selection.active;

  @override
  void dispose() {
    widget.selection.removeListener(_sync);
    _shell?.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selection = widget.selection;
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) {
        final selecting = selection.active;
        return PopScope(
          canPop: !selecting,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) selection.exit();
          },
          child: Scaffold(
            appBar: selecting
                ? DkTopBar.editing(
                    title: l.common_selected(selection.selected.length),
                    onCancel: selection.exit,
                    onDone: () => selection.selectAll(widget.all()),
                    doneLabel: l.common_select_all,
                  )
                : widget.appBar,
            body: widget.body,
            bottomNavigationBar: selecting
                ? DkSelectionBar(actions: widget.actions(selection.selected))
                : null,
          ),
        );
      },
    );
  }
}

/// The shell's bottom, which a tab's screen can take over: while [value]
/// is true the shell hides its tab bar and Scan button (selection mode puts
/// its DkSelectionBar there).
class DkShellChrome extends InheritedNotifier<ValueNotifier<bool>> {
  const DkShellChrome({
    super.key,
    required ValueNotifier<bool> tabBarHidden,
    required super.child,
  }) : super(notifier: tabBarHidden);

  /// The shell's switch, without listening to it.
  static ValueNotifier<bool>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DkShellChrome>()?.notifier;
}
