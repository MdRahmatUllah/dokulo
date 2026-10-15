import 'package:doc_vision/doc_vision.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

void main() {
  test('a photo of ink on paper: cropped to the ink, black on transparency '
      '(DK-1084)', () {
    // A light page with a shadow across it, and a dark stroke on it.
    final page = cv.Mat.fromScalar(
      600,
      800,
      cv.MatType.CV_8UC3,
      cv.Scalar.all(230),
    );
    cv.rectangle(
      page,
      cv.Rect(0, 0, 300, 600),
      cv.Scalar.all(170),
      thickness: -1,
    );
    cv.line(
      page,
      cv.Point(200, 300),
      cv.Point(600, 340),
      cv.Scalar.all(30),
      thickness: 8,
    );
    final (_, jpeg) = cv.imencode('.jpg', page);
    page.dispose();

    final png = signatureFromPhotoSync(jpeg);
    final out = cv.imdecode(png, cv.IMREAD_UNCHANGED);
    expect(out.channels, 4);
    // About the stroke's box (400 × 48) plus a small margin, not the page.
    expect(out.cols, inInclusiveRange(400, 460));
    expect(out.rows, inInclusiveRange(40, 120));
    final alpha = cv.extractChannel(out, 3);
    expect(cv.countNonZero(alpha), greaterThan(400 * 4), reason: 'the ink');
    expect(alpha.at<int>(0, 0), 0, reason: 'the paper is transparent');
    alpha.dispose();
    out.dispose();
  });

  test('a blank page has no ink', () {
    final blank = cv.Mat.fromScalar(
      200,
      200,
      cv.MatType.CV_8UC3,
      cv.Scalar.all(240),
    );
    final (_, jpeg) = cv.imencode('.jpg', blank);
    blank.dispose();
    expect(() => signatureFromPhotoSync(jpeg), throwsFormatException);
  });
}
