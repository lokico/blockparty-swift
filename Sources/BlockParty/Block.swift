public protocol Block {
	static var blockType: BlockType { get }
	var blockInstance: BlockInstance { get throws }
}

extension Block where Self: Encodable {
	public var blockInstance: BlockInstance {
		get throws {
			try BlockInstance(of: self)
		}
	}
}
