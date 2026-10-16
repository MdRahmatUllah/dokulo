# V2 edit mode: visual QA

V2 (UI spec §17.2) against the design export's `07-edit` frames. Board:
`test/screens/v2_edit/edit_screen_test.dart`, its "visual QA" group (the
real EditScreen on the invoice sample, light and dark,
`goldens/edit_qa_<frame>_<theme>.png`) and agent-2's `edit_pen_*`. Frames in
[edit/](edit/) (light, dark, German). The German of every string the frames
show is checked in the gate by `tools/check_design_de.py` (#1413).

| Task | Frame | Result |
| --- | --- | --- |
| DK-0779 | `edit-pen` | Match (`edit_pen_*`): Editing bar, the primary border, Pen selected |
| DK-0780 | `edit-penopts` | **DK-1131**: no Colour label, Custom swatch, preview box |
| DK-0782 | `edit-text` | **DK-1131**: text goes into a sheet, not inline |
| DK-0783 | `edit-shapes` | **DK-1131**: no size guide while drawing |
| DK-0784 | `edit-note` | **DK-1131**: the note sheet's layout |
| DK-0785 | `edit-annsel` | Match: dashed box, corner handles, Colour · Duplicate · Note · Delete above |
| DK-0787 | `edit-discard` | Match |
| DK-0788 | `edit-hiopts` | **DK-1131**: no Colour label, Custom swatch or preview |
| DK-0789 | `edit-textopts` | **DK-1131**: seven colours; a stepper for the size |
| DK-0790 | `edit-shapesopts` | **DK-1131**: the shape choice last; the highlighter colours |
| DK-0791 | `edit-eraser` | Match: Mode, Object · Stroke and the explanation |

**DK-1131** (P2, lane C) has the details. Two of them are §17.2's own
words, not only the frames': a text box is edited inline on the page with a
dashed outline and a caret, and shapes show their dimensions while being
drawn.

Approved: the discard dialog's buttons stack in the golden only because the
test font is wide (DkConfirmDialog stacks when the labels don't fit; the
frame's fit side by side with the app's fonts). The edit-pen frame shows a
stroke already drawn; the golden is the moment Pen is picked.

Not checked here: DK-0781 (highlighter on text) and DK-0786 (form filling)
wait for their tasks.
