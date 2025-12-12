export interface Props {
  /**
   * The person's name to greet
   */
  who: string

  /**
   * Optional greeting message (default: 'Hello')
   */
  greeting?: string
}

export default ({ who, greeting = 'Hello' }: Props) => {
  const headingStyle: React.CSSProperties = {
    fontSize: '48px',
    color: 'rgb(17, 24, 39)',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
  }
  return (<h1 style={headingStyle}>{greeting}, {who}!</h1>)
}
