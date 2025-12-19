import { useState, useEffect } from 'react'

export interface Props {
	readonly onFetch: (url: string) => Promise<string>
}

export default ({ onFetch }: Props) => {
	const [result, setResult] = useState<string>('loading...')

	useEffect(() => {
		onFetch('https://example.com').then(setResult)
	}, [onFetch])

	return <div>Result: {result}</div>
}
