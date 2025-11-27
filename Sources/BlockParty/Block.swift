/// The conforming type should be a struct of the props.
public protocol Block: Encodable {
	var blockInfo: BlockInfo { get }
}
