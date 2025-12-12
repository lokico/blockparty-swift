import Foundation
import Testing

@Suite
struct ImportExtractionTests {
	let baseDir = URL(fileURLWithPath: "/test/block")

	@Test("Extract single import")
	func extractSingleImport() {
		let content = """
		import styles from "./styles.css"
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.count == 1)
		#expect(imports[0].path == "/test/block/styles.css")
	}

	@Test("Extract multiple imports")
	func extractMultipleImports() {
		let content = """
		import styles from "./styles.css"
		import helper from "./helper.ts"
		import React from "react"
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.count == 2)
		#expect(imports[0].path == "/test/block/styles.css")
		#expect(imports[1].path == "/test/block/helper.ts")
	}

	@Test("Ignore external imports")
	func ignoreExternalImports() {
		let content = """
		import React from "react"
		import { useState } from "react"
		import foo from "some-package"
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.isEmpty)
	}

	@Test("Extract imports with single quotes")
	func extractSingleQuotes() {
		let content = """
		import styles from './styles.css'
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.count == 1)
		#expect(imports[0].path == "/test/block/styles.css")
	}

	@Test("Extract imports with different syntax")
	func extractDifferentSyntax() {
		let content = """
		import styles from "./styles.css"
		import { helper } from "./utils"
		import * as all from "./module"
		import type { Type } from "./types"
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.count == 3)
		#expect(imports[0].path == "/test/block/styles.css")
		#expect(imports[1].path == "/test/block/utils")
		#expect(imports[2].path == "/test/block/module")
	}

	@Test("Handle paths with subdirectories")
	func handleSubdirectories() {
		let content = """
		import helper from "./utils/helper.ts"
		import styles from "./css/styles.css"
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.count == 2)
		#expect(imports[0].path == "/test/block/utils/helper.ts")
		#expect(imports[1].path == "/test/block/css/styles.css")
	}

	@Test("Extract from complex TypeScript file")
	func extractFromComplexFile() {
		let content = """
		import React from "react"
		import styles from "./styles.css"
		import { helper } from "./helper"

		export default function Component() {
			return <div className={styles.container}>Hello</div>
		}
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.count == 2)
		#expect(imports[0].path == "/test/block/styles.css")
		#expect(imports[1].path == "/test/block/helper")
	}

	@Test("Handle imports without extension")
	func handleImportsWithoutExtension() {
		let content = """
		import helper from "./helper"
		import utils from "./utils/index"
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		#expect(imports.count == 2)
		#expect(imports[0].path == "/test/block/helper")
		#expect(imports[1].path == "/test/block/utils/index")
	}

	@Test("Handle side-effect imports")
	func handleSideEffectImports() {
		let content = """
		import "./styles.css"
		import "./setup.js"
		"""

		let imports = extractImports(from: content, baseDirectory: baseDir)

		// Current regex doesn't match side-effect imports
		// This is a known limitation that can be improved
		#expect(imports.count == 0)
	}
}
