import SwiftUI
import WebKit

public struct BlockView: View {
	@State private var page = WebPage()

	let blockInfo: BlockInfo

	public init(_ blockInfo: BlockInfo) {
		self.blockInfo = blockInfo
	}

	public init<B: Block>(_ makeBlock: () -> B) {
		self.blockInfo = makeBlock().blockInfo
	}

	public var body: some View {
		WebView(page)
			.task(loadingTask)
	}

	private func loadingTask() async {
		CacheManager.shared.ensureCached(blockInfo: blockInfo)

		// - Load the skeleton page with import map populated
		// - When the task is cancelled, alert the CacheManager
	}
}
