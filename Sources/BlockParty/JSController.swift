import SwiftUI
import WebKit

/// Controller that manages JavaScript execution and callback registration
class JSController: NSObject, @MainActor JSEncodingContext,
	WKScriptMessageHandler, WebPage
		.DialogPresenting
{
	nonisolated(unsafe) var loadedContinuation:
		CheckedContinuation<Void, Never>?

	// CallbackID: Args Array JSON -> JSON result (nil if function is void)
	private var syncCallbacks: [String: (String) throws -> String?] = [:]
	private var asyncCallbacks: [String: (String) async throws -> String?] =
		[:]
	private var nextCallbackId = 0

	// MARK: - JSEncodingContext

	func registerSyncCallback(
		_ callback: @escaping (String) throws -> String?
	) -> String {
		let callbackId = "sync_\(nextCallbackId)"
		nextCallbackId += 1
		syncCallbacks[callbackId] = callback

		// Return a JavaScript expression that uses prompt to synchronously call Swift
		return """
			((...args) => {
				const result = prompt('\(callbackId)', JSON.stringify(args));
				return result ? JSON.parse(result) : undefined;
			})
			"""
	}

	func registerAsyncCallback(
		_ callback: @escaping (String) async throws -> String?
	) -> String {
		let callbackId = "async_\(nextCallbackId)"
		nextCallbackId += 1
		asyncCallbacks[callbackId] = callback

		// Return a JavaScript expression that posts a message to call this callback
		return """
			(async (...args) => {
				const result = await window.webkit.messageHandlers.callback.postMessage({
					callbackId: '\(callbackId)',
					args: JSON.stringify(args)
				});
				return result ? JSON.parse(result) : undefined;
			})
			"""
	}

	// MARK: - WKScriptMessageHandler

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
		} else if message.name == "callback",
			let body = message.body as? [String: Any],
			let callbackId = body["callbackId"] as? String,
			let argsJSON = body["args"] as? String
		{
			// Handle async callback
			guard let callback = asyncCallbacks[callbackId] else {
				return
			}

			Task {
				do {
					let result = try await callback(argsJSON)
					// FIXME: Return result to JavaScript
				} catch {
					// FIXME: Better logging
					print(
						"Async JS callback '\(callbackId)' threw an error: \(error)"
					)
				}
			}
		}
	}

	// MARK: - WebPage.DialogPresenting

	func handleJavaScriptPrompt(
		message: String,
		defaultText: String?,
		initiatedBy frame: WebPage.FrameInfo
	) async -> WebPage.JavaScriptPromptResult {
		do {
			if let callback = syncCallbacks[message],
				let argsJSON = defaultText,
				let result = try callback(argsJSON)
			{
				return .ok(result)
			}
		} catch {
			// FIXME: Better logging
			print(
				"Sync JS callback '\(message)' threw an error: \(error)"
			)
		}
		return .cancel
	}
}
