import SwiftUI
import WebKit

// Message handler for JavaScript errors and events
class JavaScriptMessageHandler: NSObject, WKScriptMessageHandler {
	nonisolated(unsafe) var loadedContinuation:
		CheckedContinuation<Void, Never>?

	func userContentController(
		_ userContentController: WKUserContentController,
		didReceive message: WKScriptMessage
	) {
		if message.name == "error", let body = message.body as? [String: Any] {
			let errorMessage = body["message"] as? String ?? "Unknown error"
			let source = body["source"] as? String ?? "unknown"
			let line = body["line"] as? Int ?? 0
			let column = body["column"] as? Int ?? 0

			print("❌ JavaScript Error:")
			print("   Message: \(errorMessage)")
			print("   Source: \(source):\(line):\(column)")

			if let stack = body["stack"] as? String {
				print("   Stack: \(stack)")
			}

			if let cause = body["cause"] as? String {
				print("   Cause: \(cause)")
			}
		} else if message.name == "loaded" {
			loadedContinuation?.resume()
			loadedContinuation = nil
		}
	}
}

public struct BlockView: View {
	@State internal var page: WebPage

	let baseURL: URL
	let block: BlockInstance
	let contentController: WKUserContentController

	public init(_ block: BlockInstance, baseURL: URL) {
		self.block = block
		self.baseURL = baseURL.standardized

		// Create configuration with user content controller
		var config = WebPage.Configuration()
		let controller = WKUserContentController()
		config.userContentController = controller
		config.urlSchemeHandlers = [
			URLScheme(BundleCache.scheme)!: BundleCache.shared
		]
		self.contentController = controller

		self._page = State(initialValue: WebPage(configuration: config))
	}

	public init<B: Block>(baseURL: URL, _ makeBlock: () -> B) throws {
		try self.init(makeBlock().blockInstance, baseURL: baseURL)
	}

	public var body: some View {
		WebView(page)
			.task(load)
	}

	func load() async {
		let messageHandler = JavaScriptMessageHandler()
		contentController.add(messageHandler, name: "error")
		contentController.add(messageHandler, name: "loaded")

		let ty = block.blockType
		var baseURL = self.baseURL
		BundleCache.shared.precache(blockType: ty, baseURL: &baseURL)

		let cssLinks = ty.cssPaths.map { path in
			"<link rel=\"stylesheet\" href=\"\(path)\">"
		}.joined(separator: "\n")

		// Generate import map JSON
		let importMapJSON = try! JSONSerialization.data(
			withJSONObject: ["imports": ty.importMap],
			options: [.withoutEscapingSlashes]
		)
		let importMapString = String(data: importMapJSON, encoding: .utf8)!

		let html = """
			<!DOCTYPE html>
			<html>
			<head>
				\(cssLinks)
				<script type="importmap">
				\(importMapString)
				</script>
				<script>
					// Send JavaScript errors to Swift
					window.onerror = function(message, source, lineno, colno, error) {
						window.webkit.messageHandlers.error.postMessage({
							message: String(message),
							source: String(source || 'unknown'),
							line: lineno || 0,
							column: colno || 0,
							stack: error && error.stack ? String(error.stack) : null,
							cause: error && error.cause ? String(error.cause) : null
						});
						return false;
					};

					// Send unhandled promise rejections to Swift
					window.onunhandledrejection = function(event) {
						window.webkit.messageHandlers.error.postMessage({
							message: 'Unhandled Promise Rejection: ' + String(event.reason),
							source: 'promise',
							line: 0,
							column: 0,
							stack: event.reason && event.reason.stack ? String(event.reason.stack) : null
						});
					};
				</script>
			</head>
			<body>
				<div id="root"></div>
				<script type="module">
					try {
						const { jsx } = await import("react/jsx-runtime");
						const { createRoot } = await import("react-dom/client");
						const Block = (await import("\(ty.jsPath)")).default;
						createRoot(root).render(jsx(Block, \(block.propsJSON)));
					} catch (error) {
						window.reportError(error);
					} finally {
						window.webkit.messageHandlers.loaded.postMessage({});
					}
				</script>
			</body>
			</html>
			"""

		async let continuation: Void = withCheckedContinuation {
			messageHandler.loadedContinuation = $0
		}
		do {
			for try await _ in page.load(html: html, baseURL: baseURL) {
			}
		} catch {
			// FIXME: Handle this better
			print("Failed to load block: \(error)")
		}
		await continuation
	}
}
