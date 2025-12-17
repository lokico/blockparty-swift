public protocol Block: JSEncodable {
	static var blockType: BlockType { get }
	var blockInstance: BlockInstance { get throws }
}

extension Block {
	public var blockInstance: BlockInstance {
		get throws {
			try BlockInstance(of: self)
		}
	}
}
