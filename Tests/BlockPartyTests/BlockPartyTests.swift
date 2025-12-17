import Foundation
import SwiftUI
import Testing

@testable import BlockParty

// Simple test implementation of JSEncodingContext
class TestJSEncodingContext: JSEncodingContext {
	func registerSyncCallback(_ callback: @escaping (String) throws -> String?)
		-> String
	{
		return "(function() {})"
	}

	func registerAsyncCallback(
		_ callback: @escaping (String) async throws -> String?
	)
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

	@MainActor
	@Test("Counter-nested block with nested function callback")
	func counterNestedBlockWithNestedCallback() async throws {
		var callCount = 0
		let block = Counter_nested(
			count: 7,
			callbacks: Counter_nested.Callbacks(increment: {
				callCount += 1
			})
		)
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
		#expect((initialText as! String).contains("7 times"))

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

	@MainActor
	@Test(
		"Calculator block with function that takes parameters and returns value"
	)
	func calculatorBlockWithFunctionParameters() async throws {
		var receivedX: Double?
		var receivedY: Double?
		let block = Calculator(onCalculate: { x, y in
			receivedX = x
			receivedY = y
			return x + y
		})
		let controller = BlockViewController()
		await controller.load(block: try block.blockInstance, baseURL: baseURL)

		// Verify the result is displayed (10 + 5 = 15)
		let resultText = try await controller.page!.callJavaScript(
			"""
			const div = document.querySelector('div');
			return div ? div.textContent : null;
			"""
		)
		#expect(resultText is String)
		#expect((resultText as! String) == "Result: 15")

		// Verify the Swift callback received the correct arguments
		#expect(receivedX == 10)
		#expect(receivedY == 5)
	}

	@MainActor
	@Test("User block with nested Encodable type")
	func userBlockWithNestedEncodableType() async throws {
		// Verify at compile time that both User and User.Address are Encodable
		func assertEncodable<T: Encodable>(_: T.Type) {}
		assertEncodable(User.self)
		assertEncodable(User.Address.self)

		// Verify that User.Address has no custom jsValue by checking it uses the default implementation
		// If it has Encodable conformance, the JSEncodable protocol extension provides jsValue
		let testAddress = User.Address(
			street: "Test St",
			city: "Test City",
			zipCode: "00000"
		)
		let testContext = TestJSEncodingContext()
		let addressJSON = try testAddress.jsValue(context: testContext)

		// The default jsValue implementation for Encodable types should produce valid JSON
		#expect(addressJSON.contains("\"street\""))
		#expect(addressJSON.contains("\"Test St\""))
		#expect(addressJSON.contains("\"city\""))
		#expect(addressJSON.contains("\"Test City\""))
		#expect(addressJSON.contains("\"zipCode\""))
		#expect(addressJSON.contains("\"00000\""))

		// Now test the actual rendering
		let block = User(
			name: "Alice",
			age: 30,
			address: User.Address(
				street: "123 Main St",
				city: "Springfield",
				zipCode: "12345"
			)
		)
		let controller = BlockViewController()
		await controller.load(block: try block.blockInstance, baseURL: baseURL)

		// Verify the name and age are displayed
		let nameText = try await controller.page!.callJavaScript(
			"""
			const h2 = document.querySelector('h2');
			return h2 ? h2.textContent : null;
			"""
		)
		#expect(nameText is String)
		#expect((nameText as! String).contains("Alice"))
		#expect((nameText as! String).contains("30"))

		// Verify the address is displayed
		let addressText = try await controller.page!.callJavaScript(
			"""
			const p = document.querySelector('p');
			return p ? p.textContent : null;
			"""
		)
		#expect(addressText is String)
		let addressStr = addressText as! String
		#expect(addressStr.contains("123 Main St"))
		#expect(addressStr.contains("Springfield"))
		#expect(addressStr.contains("12345"))
	}
}
