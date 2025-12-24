# BlockParty-Swift

Use [BlockParty](https://github.com/lokico/blockparty) Blocks in SwiftUI apps. Write your UI components in React/TypeScript, and use them seamlessly in SwiftUI with full support for props, callbacks, and state updates.

## Features

- **Type-safe props**: TypeScript interfaces are automatically converted to Swift structs
- **Bidirectional callbacks**: Pass Swift closures as props that can be called from JavaScript
- **Async support**: TypeScript Promises map to Swift async functions
- **Reactive updates**: SwiftUI state changes automatically update React components
- **Nested types**: Complex object types and nested structures work seamlessly

## Quick Start

### 1. Set up your project structure

Create a `Blocks` directory next to your Swift `Sources` directory:

```
YourProject/
├── Blocks/           # Your React/TypeScript components
│   ├── Counter/
│   │   └── index.tsx
│   └── Hello/
│       └── index.tsx
├── Sources/
│   └── YourProject/
│       └── YourApp.swift
├── Package.swift
└── package.json
```

### 2. Install BlockParty

Create a `package.json` in your project root:

```json
{
  "name": "your-project",
  "version": "0.0.1",
  "devDependencies": {
    "blockparty": "0.2.0"
  }
}
```

Run:
```bash
npm install
```

### 3. Add BlockParty-Swift to your Package.swift

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YourProject",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(
            url: "https://github.com/lokico/blockparty-swift",
            from: "0.2.0"  // Use latest version <= your blockparty version
        )
    ],
    targets: [
        .executableTarget(
            name: "YourProject",
            dependencies: [
                .product(name: "BlockParty", package: "blockparty-swift")
            ],
            plugins: [
                .plugin(name: "BlockParty-Swift", package: "blockparty-swift")
            ]
        )
    ]
)
```

### 4. Create a Block

Create `Blocks/Counter/index.tsx`:

```tsx
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
```

### 5. Use it in SwiftUI

The build plugin automatically generates Swift structs for each Block. To use them in SwiftUI, create a `BlockView` containing an instance of the Block struct:

```swift
import BlockParty
import SwiftUI

struct ContentView: View {
    @State var count: Double = 0

    var body: some View {
        try! BlockView {
            Counter(
                count: count,
                increment: {
                    count += 1
                }
            )
        }
    }
}
```

### 6. Build and run

```bash
swift build
swift run
```

## Examples

### Simple Props

```tsx
// Blocks/Hello/index.tsx
export interface Props {
  who: string
  greeting?: string
}

export default ({ who, greeting = 'Hello' }: Props) => {
  return <h1>{greeting}, {who}!</h1>
}
```

```swift
try! BlockView {
    Hello(who: "World", greeting: "Hi")
}
```

### Callbacks with Parameters and Return Values

```tsx
// Blocks/Calculator/index.tsx
export interface Props {
  readonly onCalculate: (x: number, y: number) => number
}

export default ({ onCalculate }: Props) => {
  const result = onCalculate(10, 5)
  return <div>Result: {result}</div>
}
```

```swift
try! BlockView {
    Calculator(onCalculate: { x, y in
        return x + y
    })
}
```

### Async Functions

```tsx
// Blocks/Fetcher/index.tsx
export interface Props {
  readonly fetchData: (url: string) => Promise<string>
}

export default ({ fetchData }: Props) => {
  const [data, setData] = useState('loading...')

  useEffect(() => {
    fetchData('https://api.example.com/data').then(setData)
  }, [fetchData])

  return <div>{data}</div>
}
```

```swift
try! BlockView {
    Fetcher(fetchData: { url in
        let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
        return String(data: data, encoding: .utf8) ?? ""
    })
}
```

### Nested Object Types

```tsx
// Blocks/UserCard/index.tsx
export interface Props {
  readonly user: {
    readonly name: string
    readonly age: number
    readonly address: {
      readonly street: string
      readonly city: string
    }
  }
}

export default ({ user }: Props) => {
  return (
    <div>
      <h2>{user.name}, {user.age}</h2>
      <p>{user.address.street}, {user.address.city}</p>
    </div>
  )
}
```

```swift
try! BlockView {
    UserCard(
        user: UserCard.User(
            name: "Alice",
            age: 30,
            address: UserCard.User.Address(
                street: "123 Main St",
                city: "Springfield"
            )
        )
    )
}
```

### Reactive State Updates

SwiftUI state changes automatically update React components:

```swift
struct ContentView: View {
    @State var message: String = "Hello"

    var body: some View {
        VStack {
            try! BlockView {
                MessageDisplay(message: message)
            }

            Button("Change Message") {
                message = "Updated!"
            }
        }
    }
}
```

When `message` changes, the React component re-renders with the new props.

## Type Mapping

| TypeScript | Swift |
|------------|-------|
| `string` | `String` |
| `number` | `Double` |
| `boolean` | `Bool` |
| `T \| undefined` | `T?` |
| `{ x: string }` | Nested struct |
| `() => void` | `() -> Void` |
| `(x: number) => string` | `(Double) -> String` |
| `(url: string) => Promise<T>` | `(String) async -> T` |

## Configuration

### Custom Base URL

By default, blocks are served from a fake URL. You can specify a custom base URL:

```swift
try! BlockView(baseURL: URL(string: "https://mycdn.com/blocks/")) {
    MyBlock(...)
}
```

### Styling

Blocks can include CSS files that will be automatically loaded:

```
Blocks/
└── StyledComponent/
    ├── index.tsx
    └── styles.css
```

The plugin detects CSS imports and includes them in the generated code.

## How It Works

1. **Discovery**: The build plugin scans the `Blocks` directory for TypeScript/JSX files
2. **Bundling**: Each block is bundled separately using Vite
3. **Type Extraction**: TypeScript interfaces are parsed and converted to Swift types
4. **Code Generation**: Swift structs are generated with `Block` protocol conformance
5. **Runtime**: `BlockView` renders blocks in a WebKit view with Swift/JS bridge

## Requirements

- Swift 6.2+
- macOS 26.0+
- Node.js and npm (for building blocks)

## License

MIT

## Related Projects

- [BlockParty](https://github.com/lokico/blockparty) - The underlying React component system
- [BlockParty-Swift](https://github.com/lokico/blockparty-swift) - This Swift integration
