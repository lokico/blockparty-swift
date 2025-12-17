export interface Props {
	readonly name: string
	readonly age: number
	readonly address: {
		readonly street: string
		readonly city: string
		readonly zipCode: string
	}
}

export default ({ name, age, address }: Props) => (
	<div>
		<h2>{name}, {age} years old</h2>
		<p>
			{address.street}<br />
			{address.city}, {address.zipCode}
		</p>
	</div>
)
