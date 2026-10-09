import 'package:app_pdf/components/dk_editor_bars.dart';
import 'package:app_pdf/l10n/app_localizations.dart';
import 'package:app_pdf/screens/v2_edit/annotation_editor.dart';
import 'package:app_pdf/screens/v2_edit/annotation_overlay.dart';
import 'package:app_pdf/theme/app_theme.dart';
import 'package:app_pdf/theme/dk_tokens.dart';
import 'package:doc_core/doc_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A4 in points, laid out 297.5 wide: one logical pixel = 2 points.
const a4 = Size(595, 842);

void main() {
  late AnnotationEditor editor;
  AnnotRef? placed, coloured, noted;

  Future<void> pump(WidgetTester tester, {DkTokens? tokens}) async {
    tester.view.physicalSize = const Size(297.5, 421);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    placed = coloured = noted = null;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dokuloTheme(tokens ?? DkTokens.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 297.5,
            child: AnnotationOverlay(
              editor: editor,
              page: 0,
              pageSize: a4,
              onPlaced: (r) => placed = r,
              onColour: (r) => coloured = r,
              onNote: (r) => noted = r,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> drag(
    WidgetTester tester,
    List<Offset> path, {
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final g = await tester.startGesture(path.first, kind: kind);
    for (final p in path.skip(1)) {
      await g.moveTo(p);
    }
    await g.up();
    await tester.pump();
  }

  setUp(() => editor = AnnotationEditor());

  testWidgets('pen: a stroke becomes ink, in page space', (tester) async {
    await pump(tester);
    editor.tool = EditTool.pen;
    await drag(tester, const [Offset(10, 10), Offset(60, 10), Offset(60, 60)]);
    final ink = editor.annotsOn(0).single.annot as InkAnnot;
    expect(ink.strokes.single.first, (x: 20.0, y: 822.0));
    expect(ink.strokes.single.last, (x: 120.0, y: 722.0));
    expect(editor.selected, isNull, reason: 'drawing keeps drawing');
  });

  testWidgets('palm rejection: after a stylus, touches do not draw', (
    tester,
  ) async {
    await pump(tester);
    editor.tool = EditTool.pen;
    await drag(tester, const [
      Offset(10, 10),
      Offset(50, 50),
    ], kind: PointerDeviceKind.stylus);
    await drag(tester, const [Offset(100, 100), Offset(150, 150)]);
    expect(editor.annotsOn(0), hasLength(1));
  });

  testWidgets('highlighter: wide and translucent', (tester) async {
    await pump(tester);
    editor.tool = EditTool.highlighter;
    await drag(tester, const [Offset(10, 100), Offset(120, 100)]);
    final ink = editor.annotsOn(0).single.annot as InkAnnot;
    expect(ink.width, 14);
    expect(ink.color >> 24, lessThan(0xFF));
  });

  testWidgets('shapes: a drag draws a rectangle; a tap draws nothing', (
    tester,
  ) async {
    await pump(tester);
    editor.tool = EditTool.shapes;
    await drag(tester, const [Offset(20, 20), Offset(100, 80)]);
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    final shape = editor.annotsOn(0).single.annot as ShapeAnnot;
    expect(shape.rect, (left: 40.0, top: 802.0, right: 200.0, bottom: 682.0));
  });

  testWidgets(
    'text and note: a tap places one, selects it and asks for its text',
    (tester) async {
      await pump(tester);
      editor.tool = EditTool.note;
      await tester.tapAt(const Offset(30, 40));
      await tester.pump();
      expect(editor.annotsOn(0).single.annot, isA<NoteAnnot>());
      expect(placed, editor.selected);
      editor.tool = EditTool.text;
      await tester.tapAt(const Offset(100, 200));
      await tester.pump();
      expect(editor.annotsOn(0).last.annot, isA<FreeTextAnnot>());
      expect(placed, editor.selected);
    },
  );

  testWidgets('text: a tap on a text box edits it, no second box', (
    tester,
  ) async {
    await pump(tester);
    editor.tool = EditTool.text;
    await tester.tapAt(const Offset(100, 200));
    await tester.pump();
    final first = editor.selected;
    editor.select(null);
    await tester.tapAt(const Offset(110, 205));
    await tester.pump();
    expect(editor.annotsOn(0), hasLength(1));
    expect(editor.selected, first);
    expect(placed, first);
  });

  testWidgets('palm rejection holds across pages (the editor remembers)', (
    tester,
  ) async {
    editor.stylusSeen = true;
    await pump(tester);
    editor.tool = EditTool.pen;
    await drag(tester, const [Offset(100, 100), Offset(150, 150)]);
    expect(editor.annotsOn(0), isEmpty);
  });

  testWidgets('eraser: wipes the ink it touches, nothing else', (tester) async {
    editor
      ..add(
        0,
        const InkAnnot(
          [
            [(x: 20, y: 800), (x: 200, y: 800)],
          ],
          width: 2,
          color: 0xFF000000,
        ),
      )
      ..add(0, const NoteAnnot((x: 300, y: 700), note: '', color: 0xFFFFC107));
    await pump(tester);
    editor.tool = EditTool.eraser;
    await drag(tester, const [Offset(50, 0), Offset(50, 30)]);
    await drag(tester, const [Offset(150, 70), Offset(160, 75)]);
    expect(
      [for (final a in editor.annotsOn(0)) a.annot.runtimeType],
      [NoteAnnot],
    );
  });

  testWidgets('pan: tap selects, drag moves, a corner resizes; all undoable', (
    tester,
  ) async {
    final id = editor.add(
      0,
      const ShapeAnnot(
        ShapeKind.square,
        (left: 100, top: 700, right: 300, bottom: 500),
        width: 2,
        color: 0xFFE53935,
      ),
      select: false,
    );
    await pump(tester);
    editor.tool = EditTool.pan;
    // The box spans x 50-150, y 71-171 on screen.
    await tester.tapAt(const Offset(100, 120));
    await tester.pump();
    expect(editor.selected, (page: 0, id: id));
    await drag(tester, const [
      Offset(100, 120),
      Offset(110, 130),
      Offset(120, 140),
    ]);
    var rect = (editor.selectedAnnot!.annot as ShapeAnnot).rect;
    expect(rect, (left: 140.0, top: 660.0, right: 340.0, bottom: 460.0));
    // The bottom-right corner now sits at (170, 191).
    await drag(tester, const [
      Offset(170, 191),
      Offset(200, 220),
      Offset(220, 241),
    ]);
    rect = (editor.selectedAnnot!.annot as ShapeAnnot).rect;
    expect((rect.right, rect.bottom), (440.0, 360.0));
    editor
      ..undo()
      ..undo();
    expect((editor.annotsOn(0).single.annot as ShapeAnnot).rect.left, 100);
    // A tap on the empty page clears the selection.
    await tester.tapAt(const Offset(250, 380));
    await tester.pump();
    expect(editor.selected, isNull);
  });

  group('the mini bar (DK-0322)', () {
    const shape = ShapeAnnot(
      ShapeKind.square,
      (left: 100, top: 500, right: 300, bottom: 400),
      width: 2,
      color: 0xFFE53935,
    );

    testWidgets('shows over the selection; Delete is undoable', (tester) async {
      final handle = tester.ensureSemantics();
      final id = editor.add(0, shape);
      await pump(tester);
      expect(find.byType(DkAnnotBar), findsOneWidget);
      // Above the selection (its frame starts at y 171 - 4).
      expect(tester.getBottomLeft(find.byType(DkAnnotBar)).dy, lessThan(167));
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pump();
      expect(editor.annotsOn(0), isEmpty);
      expect(find.byType(DkAnnotBar), findsNothing);
      editor.undo();
      await tester.pump();
      expect(editor.annotsOn(0).single.id, id);
      handle.dispose();
    });

    testWidgets('Duplicate copies; Colour and Add note ask the host', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final id = editor.add(0, shape);
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('Colour'));
      expect(coloured, (page: 0, id: id));
      await tester.tap(find.bySemanticsLabel('Add note'));
      expect(noted, (page: 0, id: id));
      await tester.tap(find.bySemanticsLabel('Duplicate'));
      await tester.pump();
      expect(editor.annotsOn(0), hasLength(2));
      handle.dispose();
    });

    testWidgets('near the top edge it flips below', (tester) async {
      editor.add(
        0,
        const ShapeAnnot(
          ShapeKind.square,
          (left: 100, top: 835, right: 300, bottom: 760),
          width: 2,
          color: 0xFFE53935,
        ),
      );
      await pump(tester);
      expect(
        tester.getTopLeft(find.byType(DkAnnotBar)).dy,
        greaterThan(41 + 4),
      );
    });
  });

  for (final (name, tokens) in [
    ('light', DkTokens.light),
    ('dark', DkTokens.dark),
  ]) {
    testWidgets('golden: every kind, one selected ($name)', (tester) async {
      editor
        ..add(
          0,
          const InkAnnot(
            [
              [(x: 40, y: 800), (x: 120, y: 760), (x: 200, y: 800)],
            ],
            width: 3,
            color: 0xFF14171C,
          ),
        )
        ..add(
          0,
          const MarkupAnnot(MarkupKind.highlight, [
            (
              (x: 40, y: 700),
              (x: 300, y: 700),
              (x: 40, y: 684),
              (x: 300, y: 684),
            ),
          ], color: 0x80FFEB3B),
        )
        ..add(
          0,
          const MarkupAnnot(MarkupKind.strikeOut, [
            (
              (x: 40, y: 660),
              (x: 200, y: 660),
              (x: 40, y: 646),
              (x: 200, y: 646),
            ),
          ], color: 0xFFE53935),
        )
        ..add(
          0,
          const ShapeAnnot(
            ShapeKind.circle,
            (left: 340, top: 820, right: 520, bottom: 680),
            width: 3,
            color: 0xFF2251E6,
          ),
        )
        ..add(
          0,
          const FreeTextAnnot(
            (left: 60, top: 560, right: 400, bottom: 520),
            'Bitte prüfen',
            fontSize: 20,
            color: 0xFF2251E6,
          ),
        )
        ..add(
          0,
          const NoteAnnot((x: 480, y: 560), note: 'Check', color: 0xFFFFC107),
        )
        ..add(
          0,
          const ShapeAnnot(
            ShapeKind.square,
            (left: 80, top: 440, right: 300, bottom: 300),
            width: 2,
            color: 0xFFE53935,
            fill: 0x332251E6,
          ),
        );
      await pump(tester, tokens: tokens);
      await expectLater(
        find.byType(AnnotationOverlay),
        matchesGoldenFile('goldens/annotation_overlay_$name.png'),
      );
    });
  }
}
