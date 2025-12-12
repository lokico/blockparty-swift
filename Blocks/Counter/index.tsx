export interface Props {
	count: number
	increment: (() => void) | undefined
}

export default ({ count, increment }: Props) => (
	<button onClick={() => increment?.()}>Clicked {count} times</button>
)