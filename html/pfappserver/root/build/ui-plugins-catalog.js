#!/usr/bin/env node
/**
 * Admin UI plugins catalog (see docs/ui-plugins/README.md).
 *
 * src/plugins/catalog.json lists what a plugin manifest may use. This script
 * generates from it:
 *  - go/uiplugins/catalog.json, embedded in the API (manifest validation)
 *  - docs/ui-plugins/manifest.schema.json, the published manifest JSON Schema
 * and checks that src/plugins/registry.js has a loader for every component and
 * a builder for every validator.
 *
 * Usage: node build/ui-plugins-catalog.js [--check]
 *   --check  fail if a generated file is not current, writes nothing
 */
const fs = require('fs')
const path = require('path')

const root = path.resolve(__dirname, '..')
const repo = path.resolve(root, '../../..')
const catalogFile = path.join(root, 'src/plugins/catalog.json')
const registryFile = path.join(root, 'src/plugins/registry.js')
const goCatalogFile = path.join(repo, 'go/uiplugins/catalog.json')
const schemaFile = path.join(repo, 'docs/ui-plugins/manifest.schema.json')

const catalog = JSON.parse(fs.readFileSync(catalogFile, 'utf8'))
const { $comment, ...data } = catalog // eslint-disable-line no-unused-vars

const text = {
  type: 'object',
  description: 'A translatable text, by language, "en" is required.',
  required: ['en'],
  propertyNames: { pattern: '^[a-z]{2}([_-][A-Za-z]{2})?$' },
  additionalProperties: { type: 'string' },
  properties: { en: { type: 'string', minLength: 1 } }
}
const namespace = { type: 'string', pattern: '^[A-Za-z_][A-Za-z0-9_]*(\\.[A-Za-z_][A-Za-z0-9_]*)*$' }
const argSchema = { integer: { type: 'integer' }, string: { type: 'string' }, array: { type: 'array' } }

const apiPath = { type: 'string', pattern: '^[a-z0-9_.-]+(/([a-z0-9_.-]+|\\{id\\}))*$', description: 'A path relative to /api/v1, {id} is the id of the item.' }
const apiSchema = template => ({
  type: 'object',
  additionalProperties: false,
  required: ['item'],
  properties: Object.entries(data.api.methods[template]).reduce((properties, [ method, hasId ]) => {
    properties[method] = {
      ...apiPath,
      description: `${data.api.verbs[method]} ${(hasId) ? 'path with {id}' : 'path without {id}'}`,
      ...((hasId) ? { pattern: apiPath.pattern, allOf: [{ pattern: '\\{id\\}' }] } : { not: { pattern: '\\{id\\}' } })
    }
    return properties
  }, {}),
  ...((template === 'collection') ? { anyOf: [{ required: ['list'] }, { required: ['search'] }] } : {})
})

const validatorSchemas = Object.entries(data.validators).map(([fn, { args }]) => ({
  if: { properties: { fn: { const: fn } } },
  then: {
    ...((args.length) ? { required: ['args'] } : {}),
    properties: {
      args: (args.length)
        ? { type: 'array', prefixItems: args.map(kind => argSchema[kind]), minItems: args.length, maxItems: args.length }
        : { type: 'array', maxItems: 0 }
    }
  }
}))

const schema = {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'https://packetfence.org/schemas/ui-plugin-manifest.schema.json',
  title: 'PacketFence admin UI plugin manifest',
  description: 'Generated from html/pfappserver/root/src/plugins/catalog.json by html/pfappserver/root/build/ui-plugins-catalog.js, do not edit. The API also checks that every validator applies to the type of its component and that "when" references another field. See docs/ui-plugins/README.md.',
  type: 'object',
  additionalProperties: false,
  required: ['manifestVersion', 'id', 'title', 'menu', 'template', 'api', 'form'],
  properties: {
    manifestVersion: { enum: data.manifestVersions },
    id: { type: 'string', pattern: '^[a-z][a-z0-9_-]{0,62}$', description: 'The id the plugin service registered with.' },
    title: { $ref: '#/$defs/text' },
    description: { $ref: '#/$defs/text' },
    menu: {
      type: 'object',
      additionalProperties: false,
      required: ['area'],
      properties: {
        area: { enum: data.areas },
        section: { type: 'string', description: 'Path of an existing sidebar section of the area, without it the item is a new section.' },
        group: { type: 'string', description: 'Untranslated name of a group of the section.' },
        before: { type: 'string', description: 'Path of a sidebar item to insert before.' },
        after: { type: 'string', description: 'Path of a sidebar item to insert after.' },
        icon: { type: 'string', pattern: '^[a-z0-9-]+(/[a-z0-9-]+)?$', description: 'A vue-awesome icon already used by core, for a new section.' },
        can: { type: 'string', pattern: '^[a-z_]+ [a-z_]+$', description: 'The ACL needed to see the item, eg: "read system".' }
      }
    },
    template: { enum: data.templates },
    api: {
      type: 'object',
      description: `The API of the page, as in the _api.js of the core views: a path relative to /api/v1 by method, called with a fixed verb (${Object.entries(data.api.verbs).map(([ m, v ]) => `${m}: ${v}`).join(', ')}). A missing method is not offered by the page.`
    },
    collection: {
      type: 'object',
      additionalProperties: false,
      required: ['columns'],
      properties: {
        columns: {
          type: 'array',
          minItems: 1,
          items: {
            type: 'object',
            additionalProperties: false,
            required: ['key', 'label'],
            properties: { key: namespace, label: { $ref: '#/$defs/text' }, sortable: { type: 'boolean' } }
          }
        },
        searchFields: { type: 'array', items: namespace }
      }
    },
    form: {
      type: 'object',
      additionalProperties: false,
      oneOf: [{ required: ['fields'] }, { required: ['tabs'] }],
      properties: {
        fields: { type: 'array', minItems: 1, items: { $ref: '#/$defs/field' } },
        tabs: {
          type: 'array',
          minItems: 1,
          items: {
            type: 'object',
            additionalProperties: false,
            required: ['title', 'fields'],
            properties: { title: { $ref: '#/$defs/text' }, fields: { type: 'array', minItems: 1, items: { $ref: '#/$defs/field' } } }
          }
        }
      }
    }
  },
  if: { properties: { template: { const: 'collection' } } },
  then: { required: ['collection'], properties: { api: { $ref: '#/$defs/apiCollection' } } },
  else: { not: { required: ['collection'] }, properties: { api: { $ref: '#/$defs/apiResource' } } },
  $defs: {
    text,
    apiCollection: apiSchema('collection'),
    apiResource: apiSchema('resource'),
    field: {
      type: 'object',
      additionalProperties: false,
      required: ['namespace', 'component'],
      properties: {
        namespace,
        component: { enum: Object.keys(data.components) },
        label: { $ref: '#/$defs/text' },
        text: { $ref: '#/$defs/text' },
        placeholder: { $ref: '#/$defs/text' },
        props: {
          type: 'object',
          description: 'Other properties of the component (eg: options, enabledValue). Not namespace, columnLabel, text, placeholder or textFn.',
          not: { anyOf: ['namespace', 'columnLabel', 'text', 'placeholder', 'textFn'].map(p => ({ required: [p] })) }
        },
        when: {
          type: 'object',
          additionalProperties: false,
          required: ['field'],
          oneOf: [{ required: ['equals'] }, { required: ['notEquals'] }, { required: ['in'] }],
          properties: { field: namespace, equals: {}, notEquals: {}, in: { type: 'array' } }
        },
        validators: { type: 'array', items: { $ref: '#/$defs/validator' } }
      }
    },
    validator: {
      type: 'object',
      additionalProperties: false,
      required: ['fn'],
      properties: {
        fn: { enum: Object.keys(data.validators) },
        args: { type: 'array' },
        message: { $ref: '#/$defs/text' }
      },
      allOf: validatorSchemas
    }
  }
}

const outputs = {
  [goCatalogFile]: JSON.stringify(data, null, 2) + '\n',
  [schemaFile]: JSON.stringify(schema, null, 2) + '\n'
}

const errors = []

// the registry must cover the catalog: a component named only in a manifest
// is only kept in the build by its registry loader
const registry = fs.readFileSync(registryFile, 'utf8')
for (const name of Object.keys(data.components)) {
  if (!new RegExp(`\\b${name}: \\(\\) => import\\(`).test(registry))
    errors.push(`src/plugins/registry.js: no loader for the component ${name}`)
}
for (const name of Object.keys(data.validators)) {
  if (!new RegExp(`\\b(${name}|'${name}'): \\(`).test(registry))
    errors.push(`src/plugins/registry.js: no builder for the validator ${name}`)
}

const check = process.argv.includes('--check')
for (const [file, content] of Object.entries(outputs)) {
  const current = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null
  if (current === content)
    continue
  if (check)
    errors.push(`${path.relative(repo, file)} is not current, run: node html/pfappserver/root/build/ui-plugins-catalog.js`)
  else {
    fs.mkdirSync(path.dirname(file), { recursive: true })
    fs.writeFileSync(file, content)
    process.stdout.write(`wrote ${path.relative(repo, file)}\n`)
  }
}

if (errors.length) {
  process.stderr.write(errors.map(e => `[ui-plugins-catalog] ${e}\n`).join(''))
  process.exit(1)
}
