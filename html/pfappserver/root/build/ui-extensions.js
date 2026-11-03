/**
 * Build-time discovery of admin UI extensions.
 *
 * An extension is a directory with an `index.js` that default-exports a
 * definition object (see extensions/README.md). Extensions are found in:
 *
 *   1. the drop-in directory `<root>/extensions/<id>/` (gitignored), sorted by
 *      name, skipping names that start with `.` or `_`
 *   2. the `PF_UI_EXTENSIONS` environment variable, a `:` separated list of
 *      absolute paths, in the given order
 *
 * With no extension found nothing is written and the webpack configuration is
 * left untouched, so the build is the same as without this module.
 *
 * Usage from the command line:
 *   node build/ui-extensions.js --list
 */
'use strict'

const fs = require('fs')
const path = require('path')

const SUPPORTED_API_VERSIONS = [1]
const ID_RE = /^[a-z0-9][a-z0-9-]*$/
const API_VERSION_RE = /\bapiVersion\s*:\s*(\d+)/
const PO_LANG_RE = /^([a-zA-Z]{2,3}(?:[-_][a-zA-Z0-9]+)*)\.po$/
const PREFIX = '[pf-ui-extensions]'

class ExtensionError extends Error {
  constructor (message) {
    super(`${PREFIX} ${message}`)
    this.name = 'ExtensionError'
  }
}

const isDirectory = p => {
  try {
    return fs.statSync(p).isDirectory()
  } catch (e) {
    return false
  }
}

const isFile = p => {
  try {
    return fs.statSync(p).isFile()
  } catch (e) {
    return false
  }
}

const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8'))

// remove the comments (not the strings) so a commented apiVersion is not used
const stripComments = source => source.replace(/("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, (match, string) => string || '')

/**
 * List the candidate directories, drop-ins first then PF_UI_EXTENSIONS.
 */
const candidates = ({ root, env }) => {
  const list = []
  const dropin = path.join(root, 'extensions')
  if (isDirectory(dropin)) {
    fs.readdirSync(dropin)
      .filter(name => !name.startsWith('.') && !name.startsWith('_'))
      .sort()
      .forEach(name => {
        const dir = path.join(dropin, name)
        if (isDirectory(dir)) // skip README.md and other files
          list.push({ dir, source: 'drop-in' })
      })
  }
  const fromEnv = (env.PF_UI_EXTENSIONS || '')
    .split(path.delimiter)
    .map(s => s.trim())
    .filter(s => s)
  for (const dir of fromEnv) {
    if (!path.isAbsolute(dir))
      throw new ExtensionError(`PF_UI_EXTENSIONS entry "${dir}" must be an absolute path`)
    if (!isDirectory(dir))
      throw new ExtensionError(`PF_UI_EXTENSIONS entry "${dir}" is not a directory`)
    list.push({ dir, source: 'PF_UI_EXTENSIONS' })
  }
  return list
}

/**
 * Check the npm dependencies an extension declares are provided by core.
 */
const checkDependencies = ({ id, realDir, root }) => {
  const extPackage = path.join(realDir, 'package.json')
  if (!isFile(extPackage))
    return
  const core = readJson(path.join(root, 'package.json'))
  const provided = { ...core.devDependencies, ...core.dependencies }
  const ext = readJson(extPackage)
  const wanted = { ...ext.peerDependencies, ...ext.dependencies }
  const missing = Object.keys(wanted).filter(name => !(name in provided))
  if (missing.length > 0)
    throw new ExtensionError(`extension "${id}" depends on npm packages core does not provide: ${missing.join(', ')}. Add them to core package.json first.`)
}

/**
 * Find the translations shipped in `<ext>/i18n/<lang>.po`.
 */
const findTranslations = realDir => {
  const dir = path.join(realDir, 'i18n')
  const languages = {}
  if (isDirectory(dir)) {
    fs.readdirSync(dir).sort().forEach(file => {
      const match = PO_LANG_RE.exec(file)
      if (match)
        languages[match[1]] = path.join(dir, file)
    })
  }
  return languages
}

/**
 * Discover and validate the extensions. Throws an ExtensionError on any
 * misconfiguration so the build fails with a clear message.
 */
const discoverExtensions = ({ root, env = process.env } = {}) => {
  const realRoot = fs.realpathSync(root)
  const byRealDir = new Map()
  const byId = new Map()
  const extensions = []
  for (const { dir, source } of candidates({ root, env })) {
    const realDir = fs.realpathSync(dir)
    if (byRealDir.has(realDir)) {
      // eslint-disable-next-line no-console
      console.warn(`${PREFIX} "${dir}" is the same directory as "${byRealDir.get(realDir)}", ignored`)
      continue
    }
    byRealDir.set(realDir, dir)
    const id = path.basename(dir)
    if (!ID_RE.test(id))
      throw new ExtensionError(`extension directory "${dir}": the name "${id}" must match ${ID_RE}`)
    if (byId.has(id))
      throw new ExtensionError(`two extensions have the id "${id}": "${byId.get(id)}" and "${dir}"`)
    byId.set(id, dir)
    if (realDir.split(path.sep).includes('node_modules'))
      throw new ExtensionError(`extension "${id}" (${realDir}) is inside a node_modules directory, it would not be transpiled`)
    if (fs.existsSync(path.join(realDir, 'node_modules')))
      throw new ExtensionError(`extension "${id}" has its own node_modules directory (${realDir}/node_modules), remove it: it would load a second copy of Vue/Vuex`)
    const entry = path.join(realDir, 'index.js')
    if (!isFile(entry))
      throw new ExtensionError(`extension "${id}" has no index.js (${entry})`)
    const match = API_VERSION_RE.exec(stripComments(fs.readFileSync(entry, 'utf8')))
    if (!match)
      throw new ExtensionError(`extension "${id}" does not declare a literal "apiVersion" in index.js, supported: ${SUPPORTED_API_VERSIONS.join(', ')}`)
    const apiVersion = +match[1]
    if (!SUPPORTED_API_VERSIONS.includes(apiVersion))
      throw new ExtensionError(`extension "${id}" uses apiVersion ${apiVersion}, supported: ${SUPPORTED_API_VERSIONS.join(', ')}`)
    checkDependencies({ id, realDir, root })
    extensions.push({
      id,
      dir,
      realDir,
      source,
      apiVersion,
      outsideRoot: !(realDir + path.sep).startsWith(realRoot + path.sep),
      languages: findTranslations(realDir)
    })
  }
  return extensions
}

/**
 * Minimal PO parser: msgid/msgstr pairs, continuation lines and the usual
 * C escapes. Entries without a translation, fuzzy ones, plurals and the header
 * are skipped.
 */
const unescapePo = s => s.replace(/\\(["\\nrt])/g, (m, c) => ({ n: '\n', r: '\r', t: '\t' }[c] || c))

const parsePo = content => {
  const messages = {}
  let entry = {}
  let key = null
  const flush = () => {
    if (entry.msgid && entry.msgstr && !('msgid_plural' in entry) && !entry.fuzzy)
      messages[entry.msgid] = entry.msgstr
    entry = {}
    key = null
  }
  for (const raw of content.split(/\r?\n/)) {
    const line = raw.trim()
    if (line === '') {
      flush()
      continue
    }
    if (line.startsWith('#')) {
      if (/^#,.*\bfuzzy\b/.test(line)) {
        if ('msgstr' in entry)
          flush()
        entry.fuzzy = true
      }
      continue
    }
    let match = /^(msgid|msgid_plural|msgstr|msgctxt)\s+"(.*)"$/.exec(line)
    if (match) {
      if (match[1] === 'msgid' && 'msgstr' in entry)
        flush()
      key = match[1]
      entry[key] = unescapePo(match[2])
      continue
    }
    match = /^"(.*)"$/.exec(line)
    if (match && key) {
      entry[key] += unescapePo(match[1])
    }
  }
  flush()
  return messages
}

const writeIfChanged = (file, content) => {
  if (isFile(file) && fs.readFileSync(file, 'utf8') === content)
    return
  fs.mkdirSync(path.dirname(file), { recursive: true })
  fs.writeFileSync(file, content)
}

/**
 * Write the registry module (and the translation JSON files) imported in place
 * of src/extensions/registry.js. Returns the path of the registry module.
 */
const writeRegistry = (outDir, extensions) => {
  const imports = []
  const entries = []
  extensions.forEach(({ id, languages }, n) => {
    imports.push(`import ext${n} from ${JSON.stringify(`@pf-ext/${id}/index.js`)}`)
    const messages = Object.keys(languages).map(lang => {
      const json = path.join(outDir, 'i18n', id, `${lang}.json`)
      writeIfChanged(json, JSON.stringify(parsePo(fs.readFileSync(languages[lang], 'utf8')), null, 2) + '\n')
      const request = `./${path.relative(outDir, json).split(path.sep).join('/')}`
      return `      ${JSON.stringify(lang)}: () => import(/* webpackChunkName: ${JSON.stringify(`ext-i18n-${lang}`)} */ ${JSON.stringify(request)})`
    })
    entries.push([
      '  {',
      `    id: ${JSON.stringify(id)},`,
      `    definition: ext${n},`,
      `    messages: {${messages.length ? `\n${messages.join(',\n')}\n    ` : ''}}`,
      '  }'
    ].join('\n'))
  })
  const file = path.join(outDir, 'registry.js')
  writeIfChanged(file, [
    '// AUTO-GENERATED by build/ui-extensions.js, do not edit',
    ...imports,
    '',
    'export default [',
    entries.join(',\n'),
    ']',
    ''
  ].join('\n'))
  return file
}

module.exports = {
  SUPPORTED_API_VERSIONS,
  ExtensionError,
  discoverExtensions,
  parsePo,
  stripComments,
  writeRegistry
}

if (require.main === module) {
  const root = path.resolve(__dirname, '..')
  if (process.argv.includes('--list')) {
    const list = discoverExtensions({ root })
    process.stdout.write(JSON.stringify(list, null, 2) + '\n')
  } else {
    process.stderr.write('usage: node build/ui-extensions.js --list\n')
    process.exit(1)
  }
}
