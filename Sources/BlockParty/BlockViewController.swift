import Observation
import SwiftUI
import WebKit

@MainActor
@Observable
class BlockViewController {

	@MainActor
	private struct LoadedState {
		var page: WebPage
		var blockType: BlockType
		var jsController: JSController
	}
	private var state: LoadedState? = nil

	public var page: WebPage? { state?.page }

	public init() {}

	public func load(block: BlockInstance, baseURL: URL? = nil) async {
		let ty = block.blockType
		let jsController = state?.jsController ?? JSController()

		// Generate props using the JSController as context
		let propsJS: String
		do {
			propsJS = try block.makeProps(jsController)
		} catch {
			print("Failed to encode props: \(error)")
			return
		}

		guard !Task.isCancelled else { return }

		// If the block type is the same as before, we can just update the props
		if let state = self.state, ty == state.blockType {
			do {
				_ = try await state.page.callJavaScript(
					"""
					window.__updateProps(\(propsJS));
					"""
				)
				return
			} catch {
				print("Failed to update props: \(error)")
				print("Falling back to reloading the page")
			}
		}

		var baseURL = baseURL ?? URL(string: "/")!
		BundleCache.shared.precache(blockType: ty, baseURL: &baseURL)

		let cssLinks = ty.cssPaths.map { path in
			"<link rel=\"stylesheet\" href=\"\(path)\">"
		}.joined(separator: "\n")

		// Generate import map JSON
		let importMapString: String
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = .withoutEscapingSlashes
			let importMapJSON = try encoder.encode(["imports": ty.importMap])
			importMapString =
				"<script type=\"importmap\">\n"
				+ (try dataToUTF8String(importMapJSON)) + "\n</script>"
		} catch {
			print("Failed to encode import map: \(error)")
			print("Trying without import map")
			importMapString = ""
		}

		let html = """
			<!DOCTYPE html>
			<html>
			<head>
				\(cssLinks)
				\(importMapString)
				<script>
					// Helper to safely stringify callback arguments
					// Handles non-serializable objects like React events
					window.__safeStringifyArgs = function(args) {
						try {
							return JSON.stringify(args.map(arg => {
								// Try to stringify each argument individually
								try {
									JSON.stringify(arg);
									return arg;
								} catch {
									// If it fails (like with circular refs or events), return null
									return null;
								}
							}));
						} catch {
							return '[]';
						}
					};

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
						const root = createRoot(document.getElementById('root'));
						root.render(jsx(Block, \(propsJS)));

						// Store update function for Swift to call
						window.__updateProps = function(newProps) {
							root.render(jsx(Block, newProps));
						};
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
		config.userContentController = jsController.userContentController
		config.urlSchemeHandlers = [
			URLScheme(BundleCache.scheme)!: BundleCache.shared
		]

		guard !Task.isCancelled else { return }

		// Create and load the WebPage
		let pg = WebPage(configuration: config, dialogPresenter: jsController)

		async let continuation: Void = withCheckedContinuation {
			jsController.loadedContinuation = $0
		}
		do {
			for try await _ in pg.load(html: html, baseURL: baseURL) {
			}
		} catch {
			print("Failed to load block: \(error)")
		}
		await continuation

		// Prevent flicker if we're already out of date
		guard !Task.isCancelled else { return }
		state = LoadedState(page: pg, blockType: ty, jsController: jsController)
	}
}
