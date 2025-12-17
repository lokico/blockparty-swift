import SwiftUI
import WebKit

public struct BlockView: View {
	@State var controller: BlockViewController = BlockViewController()

	let baseURL: URL
	let block: BlockInstance

	public init(_ block: BlockInstance, baseURL: URL) {
		self.block = block
		self.baseURL = baseURL.standardized
	}

	public init<B: Block>(baseURL: URL, _ makeBlock: () throws -> B) throws {
		let instance = try makeBlock().blockInstance
		self.init(instance, baseURL: baseURL)
	}

	public var body: some View {
		var result: _ConditionalContent<WebView, EmptyView>
		if let page = controller.page {
			result = ViewBuilder.buildEither(first: WebView(page))
		} else {
			result = ViewBuilder.buildEither(second: EmptyView())
		}
		return result.task {
			await controller.load(block: block, baseURL: baseURL)
		}
	}
}
