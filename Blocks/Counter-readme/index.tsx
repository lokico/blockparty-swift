export interface Props {
  readonly count: number
  readonly increment?: () => void
}

export default ({ count, increment }: Props) => {
  return (
    <button onClick={increment}>
      Clicked {count} times
    </button>
  )
}
