import Foundation
import SwiftUI
import Testing

@testable import BlockParty

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

		#expect(info.blockType.jsPath == "./test.js")
		#expect(info.propsJSON.contains("\"name\":\"Alice\""))
		#expect(info.propsJSON.contains("\"count\":42"))
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
		#expect(info1.propsJSON.contains("\"optional\":\"maybe\""))

		let blockWithoutOptional = TestBlock(required: "yes", optional: nil)
		let info2 = try blockWithoutOptional.blockInstance
		#expect(!info2.propsJSON.contains("\"optional\":"))
	}

	@Test("Generated blocks conform to Block protocol")
	func generatedBlocksConformToProtocol() throws {
		// This test verifies that the generated code compiles and works correctly
		let counter = Counter(count: 5, increment: "increment callback")
		let info = try counter.blockInstance

		#expect(info.blockType.jsPath == "./Counter/index.js")
		#expect(info.propsJSON.contains("\"count\":5"))
		#expect(info.propsJSON.contains("\"increment\":"))
	}

	@Test("Generated Hello_css block with optional props")
	func helloCssBlockWithOptionalProps() throws {
		// Test with optional greeting
		let block1 = Hello_css(who: "World", greeting: "Hi")
		let info1 = try block1.blockInstance

		#expect(info1.blockType.jsPath == "./Hello-css/index.js")
		#expect(info1.blockType.cssPaths == ["./Hello-css/style.css"])
		#expect(info1.propsJSON.contains("\"who\":\"World\""))
		#expect(info1.propsJSON.contains("\"greeting\":\"Hi\""))

		// Test without optional greeting
		let block2 = Hello_css(who: "Alice", greeting: nil)
		let info2 = try block2.blockInstance

		#expect(info2.propsJSON.contains("\"who\":\"Alice\""))
		#expect(!info2.propsJSON.contains("\"greeting\":"))
	}

	@Test("Generated Hello_inline block")
	func helloInlineBlock() throws {
		let block = Hello_inline(who: "Bob", greeting: nil)
		let info = try block.blockInstance

		#expect(info.blockType.jsPath == "./Hello-inline/index.js")
		#expect(info.blockType.cssPaths.isEmpty)
		#expect(info.propsJSON.contains("\"who\":\"Bob\""))
		#expect(!info.propsJSON.contains("\"greeting\":"))
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
		let view = try BlockView(block.blockInstance, baseURL: baseURL)
		await load(blockView: view)

		// Execute JavaScript to check if styles are applied
		let result = try await view.page.callJavaScript(
			"""
			const elem = document.querySelector('h1');
			return elem ? window.getComputedStyle(elem).color : null;
			""",
			arguments: [:],
			in: nil,
			contentWorld: .page
		)

		// Verify the color is red (rgb(255, 0, 0))
		#expect(result is String)
		let colorValue = result as! String
		#expect(colorValue == "rgb(17, 24, 39)")
	}

	@MainActor
	private func load(blockView view: BlockView) async {
		let controller = NSHostingController(rootView: view)
		controller.loadViewIfNeeded()
		await view.load()
	}
}
