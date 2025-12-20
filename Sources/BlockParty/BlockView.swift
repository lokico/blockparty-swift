import SwiftUI
import WebKit

public struct BlockView: View {
	@State var controller: BlockViewController = BlockViewController()

	let baseURL: URL?
	let block: BlockInstance

	public init(_ block: BlockInstance, baseURL: URL? = nil) {
		self.block = block
		self.baseURL = baseURL?.standardized
	}

	public init<B: Block>(baseURL: URL? = nil, _ makeBlock: () throws -> B)
		throws
	{
		let instance = try makeBlock().blockInstance
		self.init(instance, baseURL: baseURL)
	}

	public var body: some View {
		var result: _ConditionalContent<WebView, Color>
		if let page = controller.page {
			result = ViewBuilder.buildEither(first: WebView(page))
		} else {
			// Can't use EmptyView because that doesn't trigger the task
			result = ViewBuilder.buildEither(second: Color.clear)
		}
		return result.task(
			// Ensure this runs every time..
			// FIXME: Can we optimize and not?
			id: UUID()
		) {
			await controller.load(block: block, baseURL: baseURL)
		}
	}
}
