import Observation
import SwiftUI
import WebKit

@MainActor
@Observable
class BlockViewController {
	private var loading: Bool = false
	public private(set) var page: WebPage?

	public init() {}

	public func load(block: BlockInstance, baseURL: URL) async {
		precondition(!loading)
		loading = true
		defer { loading = false }

		if let page = page {
			// FIXME: Update
			return
		}

		let ty = block.blockType
		var baseURL = baseURL
		BundleCache.shared.precache(blockType: ty, baseURL: &baseURL)

		// Create the JS controller which serves as the encoding context
		let jsController = JSController()

		// Generate props using the JS controller as context
		let propsJS: String
		do {
			propsJS = try block.makeProps(jsController)
		} catch {
			print("Failed to encode props: \(error)")
			return
		}

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
						createRoot(root).render(jsx(Block, \(propsJS)));
					} catch (error) {
						window.reportError(error);
					} finally {
						window.webkit.messageHandlers.loaded.postMessage({});
					}
				</script>
			</body>
			</html>
			"""

		// Create the WebPage configuration
		var config = WebPage.Configuration()
		let controller = WKUserContentController()
		config.userContentController = controller
		config.urlSchemeHandlers = [
			URLScheme(BundleCache.scheme)!: BundleCache.shared
		]

		controller.add(jsController, name: "error")
		controller.add(jsController, name: "loaded")
		controller.add(jsController, name: "callback")

		// Create and load the WebPage
		let pg = WebPage(configuration: config, dialogPresenter: jsController)

		async let continuation: Void = withCheckedContinuation {
			jsController.loadedContinuation = $0
		}
		do {
			for try await _ in pg.load(html: html, baseURL: baseURL) {
			}
		} catch {
			// FIXME: Handle this better
			print("Failed to load block: \(error)")
		}
		await continuation
		page = pg
	}
}
