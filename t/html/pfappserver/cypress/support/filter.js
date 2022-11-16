/// <reference types="Cypress" />
const _describe = describe

const parseBool = s => {
  return Function(`'use strict'; return (${s})`)()
}

const isTagged = tags => {
  let wants = (Cypress.env('tags') || [])
    .map(tag => `${tag}`.trim().toLowerCase())
    .filter(tag => tag)

  if (wants.length) {
    wants = Array.isArray(wants) ? wants : [wants]
    let bool = false
    wants.forEach(want => {
      want.match(/([a-z-]+)/gi).forEach(tag => {
        want = want.replace(tag, tags.includes(tag))
      })
      bool = bool || parseBool(want)
    })
    return bool
  }

  return true
}

describe = function describeFiltered(name, config, callback) {
  if (config && config.constructor === Function) {
    callback = config
    config = {}
  }
  let { tags } = config || {}
  tags = Array.isArray(tags) ? tags : [tags]
  if (tags.length) {
    name += ` ${JSON.stringify(tags)}`
    if (!isTagged(tags)) {
      _describe.skip(name, config, callback)
      return
    }
  }
  _describe(name, config, callback)
  return
}

context = describe