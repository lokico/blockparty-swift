import Foundation
import SwiftUI
import Testing

@testable import BlockParty

// Simple test implementation of JSEncodingContext
class TestJSEncodingContext: JSEncodingContext {
	func registerSyncCallback(_ callback: @escaping (String?) -> String?)
		-> String
	{
		return "(function() {})"
	}

	func registerAsyncCallback(_ callback: @escaping (String?) async -> String?)
		-> String
	{
		return "(async function() {})"
	}
}

@Suite
struct BlockPartyTests {
	let baseURL = URL(string: "https://this.site.should.not.exist.abojdgwa/")!

	@Test("BlockInstance encodes props correctly")
	func blockInstanceEncodesProps() throws {
		struct TestBlock: Encodable, Block {
			let name: String
			let count: Int

			static var blockType: BlockType {
				BlockType(js: "./test.js")
			}
		}

		let block = TestBlock(name: "Alice", count: 42)
		let info = try block.blockInstance
		let propsJS = try info.makeProps(TestJSEncodingContext())

		#expect(info.blockType.jsPath == "./test.js")
		#expect(propsJS.contains("\"name\":\"Alice\""))
		#expect(propsJS.contains("\"count\":42"))
	}

	@Test("BlockInstance handles optional props")
	func blockInstanceHandlesOptionalProps() throws {
		struct TestBlock: Block, Encodable {
			let required: String
			let optional: String?

			static var blockType: BlockType {
				BlockType(js: "./test.js")
			}
		}

		let blockWithOptional = TestBlock(required: "yes", optional: "maybe")
		let info1 = try blockWithOptional.blockInstance
		let propsJS1 = try info1.makeProps(TestJSEncodingContext())
		#expect(propsJS1.contains("\"optional\":\"maybe\""))

		let blockWithoutOptional = TestBlock(required: "yes", optional: nil)
		let info2 = try blockWithoutOptional.blockInstance
		let propsJS2 = try info2.makeProps(TestJSEncodingContext())
		#expect(!propsJS2.contains("\"optional\":"))
	}

	@Test("Generated Hello_css block with optional props")
	func helloCssBlockWithOptionalProps() throws {
		// Test with optional greeting
		let block1 = Hello_css(who: "World", greeting: "Hi")
		let info1 = try block1.blockInstance
		let propsJS1 = try info1.makeProps(TestJSEncodingContext())

		#expect(info1.blockType.jsPath == "./Hello-css/index.js")
		#expect(info1.blockType.cssPaths == ["./Hello-css/style.css"])
		#expect(propsJS1.contains("\"who\":\"World\""))
		#expect(propsJS1.contains("\"greeting\":\"Hi\""))

		// Test without optional greeting
		let block2 = Hello_css(who: "Alice", greeting: nil)
		let info2 = try block2.blockInstance
		let propsJS2 = try info2.makeProps(TestJSEncodingContext())

		#expect(propsJS2.contains("\"who\":\"Alice\""))
		#expect(!propsJS2.contains("\"greeting\":"))
	}

	@Test("Generated Hello_inline block")
	func helloInlineBlock() throws {
		let block = Hello_inline(who: "Bob", greeting: nil)
		let info = try block.blockInstance
		let propsJS = try info.makeProps(TestJSEncodingContext())

		#expect(info.blockType.jsPath == "./Hello-inline/index.js")
		#expect(info.blockType.cssPaths.isEmpty)
		#expect(propsJS.contains("\"who\":\"Bob\""))
		#expect(!propsJS.contains("\"greeting\":"))
	}

	@MainActor
	@Test("BlockView construction with generated blocks")
	func blockViewConstruction() throws {
		let view = try BlockView(baseURL: baseURL) {
			Hello_inline(who: "Test", greeting: "Hello")
		}

		#expect(view.block.blockType.jsPath == "./Hello-inline/index.js")
	}

	@MainActor
	@Test(
		"Inline styles and external CSS both work",
		arguments: [Hello_inline.init, Hello_css.init]
	)
	func blockViewHelloInlineStyles(
		ctor: @Sendable (String, String?) -> any Block
	)
		async throws
	{
		let block = ctor("World", "Greetings")
		let controller = BlockViewController()
		await controller.load(block: try block.blockInstance, baseURL: baseURL)

		// Execute JavaScript to check if styles are applied
		let result = try await controller.page!.callJavaScript(
			"""
			const elem = document.querySelector('h1');
			return elem ? window.getComputedStyle(elem).color : null;
			"""
		)

		// Verify the color is red (rgb(255, 0, 0))
		#expect(result is String)
		let colorValue = result as! String
		#expect(colorValue == "rgb(17, 24, 39)")

		// Verify the text content
		let textResult = try await controller.page!.callJavaScript(
			"""
			const elem = document.querySelector('h1');
			return elem ? elem.textContent : null;
			"""
		)

		#expect(textResult is String)
		let textValue = textResult as! String
		#expect(textValue == "Greetings, World!")
	}

	@MainActor
	@Test("Counter block with function callback")
	func counterBlockWithFunctionCallback() async throws {
		var callCount = 0
		let block = Counter(count: 5) {
			callCount += 1
		}
		let controller = BlockViewController()
		await controller.load(block: try block.blockInstance, baseURL: baseURL)

		// Verify initial count is displayed
		let initialText = try await controller.page!.callJavaScript(
			"""
			const button = document.querySelector('button');
			return button ? button.textContent : null;
			"""
		)
		#expect(initialText is String)
		#expect((initialText as! String).contains("5 times"))

		// Click the button programmatically
		try await controller.page!.callJavaScript(
			"""
			const button = document.querySelector('button');
			button.click();
			"""
		)

		// Wait a bit for the callback to be processed
		try await Task.sleep(for: .milliseconds(100))

		// Verify the Swift callback was called
		#expect(callCount == 1)
	}
}
