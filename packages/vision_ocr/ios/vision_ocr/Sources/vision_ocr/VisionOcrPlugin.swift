import Flutter
import UIKit
import Vision

/// Apple Vision text recognition (DK-0397). `recognize` takes an image path and
/// language hints and answers a list of words: text, a normalised top-left-origin
/// box [left, top, width, height] and the line's confidence. The work runs on a
/// background queue; the answer comes back on the main queue.
public class VisionOcrPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dokulo/vision_ocr", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(VisionOcrPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognize",
      let args = call.arguments as? [String: Any],
      let path = args["path"] as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    let languages = args["languages"] as? [String] ?? ["de-DE", "en-US"]
    DispatchQueue.global(qos: .userInitiated).async {
      let answer = Self.recognize(path: path, languages: languages)
      DispatchQueue.main.async { result(answer) }
    }
  }

  private static func recognize(path: String, languages: [String]) -> Any {
    guard let image = UIImage(contentsOfFile: path)?.cgImage else {
      return FlutterError(code: "not_an_image", message: "Vision can't read this image", details: nil)
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = languages
    request.usesLanguageCorrection = true
    do {
      try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    } catch {
      return FlutterError(code: "failed", message: error.localizedDescription, details: nil)
    }
    var words: [[String: Any]] = []
    for line in request.results ?? [] {
      guard let candidate = line.topCandidates(1).first else { continue }
      let text = candidate.string
      // One entry per word: Vision boxes a range of the line's string.
      text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, range, _, _ in
        guard let word = word,
          let box = try? candidate.boundingBox(for: range)?.boundingBox
        else { return }
        words.append([
          "text": word,
          // Vision's origin is the bottom left; Dokulo's is the top left.
          "box": [box.minX, 1 - box.maxY, box.width, box.height],
          "confidence": Double(candidate.confidence),
        ])
      }
    }
    return words
  }
}
