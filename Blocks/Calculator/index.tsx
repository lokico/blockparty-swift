export interface Props {
	readonly onCalculate: (x: number, y: number) => number
}

export default ({ onCalculate }: Props) => {
	const result = onCalculate(10, 5)
	return <div>Result: {result}</div>
}
