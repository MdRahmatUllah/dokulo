import Flutter
import UIKit
import WebKit

/// Web page or HTML to a paginated PDF (DK-0399): an off-screen WKWebView,
/// printed through UIPrintPageRenderer into pages of the chosen size
/// (WKWebView.createPDF would give one endless page).
public class WebToPdfPlugin: NSObject, FlutterPlugin {
  private var jobs = Set<PrintJob>()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "dokulo/web_to_pdf", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(WebToPdfPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "print", let args = call.arguments as? [String: Any],
      let output = args["output"] as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    let job = PrintJob(args: args, output: URL(fileURLWithPath: output))
    jobs.insert(job)
    job.start { [weak self, weak job] answer in
      if let job = job { self?.jobs.remove(job) }
      result(answer)
    }
  }
}

final class PrintJob: NSObject, WKNavigationDelegate {
  private let args: [String: Any]
  private let output: URL
  private let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1000))
  private var done: ((Any) -> Void)?

  init(args: [String: Any], output: URL) {
    self.args = args
    self.output = output
  }

  func start(_ done: @escaping (Any) -> Void) {
    self.done = done
    web.navigationDelegate = self
    let timeout = Double(args["timeoutMs"] as? Int ?? 30000) / 1000
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
      self?.finish(FlutterError(code: "timeout", message: "The page took longer than \(Int(timeout)) s", details: nil))
    }
    if let html = args["html"] as? String {
      web.loadHTMLString(html, baseURL: (args["baseUrl"] as? String).flatMap(URL.init(string:)))
    } else if let url = (args["url"] as? String).flatMap(URL.init(string:)) {
      web.load(URLRequest(url: url))
    } else {
      finish(FlutterError(code: "failed", message: "Nothing to load", details: nil))
    }
  }

  private func finish(_ answer: Any) {
    guard let done = done else { return }
    self.done = nil
    web.stopLoading()
    done(answer)
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    finish(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    finish(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    if args["backgrounds"] as? Bool ?? true {
      webView.evaluateJavaScript(
        "(function(){var s=document.createElement('style');"
          + "s.textContent='*{-webkit-print-color-adjust:exact !important;print-color-adjust:exact !important}';"
          + "document.head.appendChild(s)})()")
    }
    // Let late layout settle, then print.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.render() }
  }

  private func render() {
    guard done != nil else { return }
    // Points: A4 595.28 × 841.89, Letter 612 × 792; "Default" margins 36 pt (12.7 mm).
    let paper =
      args["pageSize"] as? String == "letter"
      ? CGRect(x: 0, y: 0, width: 612, height: 792) : CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
    let inset: CGFloat = args["margins"] as? Bool ?? true ? 36 : 0
    let renderer = UIPrintPageRenderer()
    renderer.addPrintFormatter(web.viewPrintFormatter(), startingAtPageAt: 0)
    renderer.setValue(NSValue(cgRect: paper), forKey: "paperRect")
    renderer.setValue(NSValue(cgRect: paper.insetBy(dx: inset, dy: inset)), forKey: "printableRect")
    let pages = renderer.numberOfPages
    let data = UIGraphicsPDFRenderer(bounds: paper).pdfData { context in
      renderer.prepare(forDrawingPages: NSRange(location: 0, length: pages))
      for page in 0..<pages {
        context.beginPage()
        renderer.drawPage(at: page, in: context.pdfContextBounds)
      }
    }
    do {
      try data.write(to: output)
      finish(pages)
    } catch {
      finish(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
    }
  }
}
