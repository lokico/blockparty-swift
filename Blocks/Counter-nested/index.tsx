export interface Props {
	readonly count: number
	readonly callbacks: { increment: () => void }
}

export default ({ count, callbacks: { increment } }: Props) => (
	<button onClick={() => increment()}>Clicked {count} times</button>
)
