import styles from './styles.module.css'
import styles2 from './styles2.module.css'

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
  return (<h1 className={`${styles.heading} ${styles2.dark}`}>{greeting}, {who}!</h1>)
}
