/**
 * HTML of the texts built with values (names, IDs, messages) that are
 * rendered with v-html: only the formatting elements and attributes are kept.
 *
 * The HTML is parsed in a <template> element (its content is inert: the
 * scripts are not run, the resources are not loaded). Then:
 * - the elements of DROPPED_TAGS are removed with their content;
 * - the elements not in ALLOWED_TAGS are replaced with their content;
 * - only the attributes of ALLOWED_ATTRIBUTES are kept, href only with an
 *   http, https or mailto URL or a relative URL.
 *
 * The nodes are walked with the methods and getters of the Node and Element
 * prototypes: a form exposes its controls as properties (ex: an
 * <input name="childNodes"> replaces form.childNodes), a parsed document its
 * named elements (ex: <img name="body">), these must not change what is
 * walked or removed.
 */

const ALLOWED_TAGS = new Set([
  'a', 'b', 'br', 'code', 'div', 'em', 'hr', 'i', 'kbd', 'li', 'mark', 'ol',
  'p', 'pre', 'samp', 'small', 'span', 'strong', 'sub', 'sup', 'u', 'ul'
])

const DROPPED_TAGS = new Set([
  'embed', 'iframe', 'link', 'math', 'meta', 'noscript', 'object', 'script',
  'style', 'svg', 'template', 'textarea', 'title'
])

const ALLOWED_ATTRIBUTES = {
  '*': new Set(['class', 'title']),
  a: new Set(['href', 'target', 'rel'])
}

const ALLOWED_URL_SCHEMES = new Set(['http', 'https', 'mailto'])

export const isAllowedUrl = (url) => {
  // browsers ignore the control characters and whitespaces in a scheme
  // eslint-disable-next-line no-control-regex
  const compact = String(url).replace(/[\u0000-\u0020\u007f]/g, '')
  const scheme = /^([a-z][a-z0-9+.-]*):/i.exec(compact)
  return !scheme || ALLOWED_URL_SCHEMES.has(scheme[1].toLowerCase())
}

const isAllowedAttribute = (tag, name, value) => {
  if (!(ALLOWED_ATTRIBUTES['*'].has(name) || (ALLOWED_ATTRIBUTES[tag] && ALLOWED_ATTRIBUTES[tag].has(name)))) {
    return false
  }
  return (name === 'href') ? isAllowedUrl(value) : true
}

const getter = (proto, name) => Object.getOwnPropertyDescriptor(proto, name).get
const getChildNodes = getter(Node.prototype, 'childNodes')
const getFirstChild = getter(Node.prototype, 'firstChild')
const getNodeName = getter(Node.prototype, 'nodeName')
const getNodeType = getter(Node.prototype, 'nodeType')
const getAttributes = getter(Element.prototype, 'attributes')
const { insertBefore, removeChild } = Node.prototype
const { getAttribute, removeAttribute, setAttribute } = Element.prototype

// replaces a node with its children
const unwrap = (parent, node) => {
  let child
  while ((child = getFirstChild.call(node))) {
    insertBefore.call(parent, child, node)
  }
  removeChild.call(parent, node)
}

const sanitizeChildren = (parent) => {
  Array.from(getChildNodes.call(parent)).forEach(node => {
    const type = getNodeType.call(node)
    if (type === Node.TEXT_NODE) {
      return
    }
    if (type !== Node.ELEMENT_NODE) { // comments, processing instructions...
      removeChild.call(parent, node)
      return
    }
    const tag = getNodeName.call(node).toLowerCase()
    if (DROPPED_TAGS.has(tag)) {
      removeChild.call(parent, node)
      return
    }
    sanitizeChildren(node)
    if (!ALLOWED_TAGS.has(tag)) {
      unwrap(parent, node)
      return
    }
    Array.from(getAttributes.call(node)).forEach(({ name, value }) => {
      if (!isAllowedAttribute(tag, name.toLowerCase(), value)) {
        removeAttribute.call(node, name)
      }
    })
    if (tag === 'a' && getAttribute.call(node, 'target') === '_blank') {
      setAttribute.call(node, 'rel', 'noopener noreferrer')
    }
  })
}

export const sanitizeHtml = (html) => {
  if (html === undefined || html === null || html === '') {
    return ''
  }
  const template = document.createElement('template')
  template.innerHTML = String(html)
  sanitizeChildren(template.content)
  return template.innerHTML
}

export const pfSanitizeHtmlPlugin = {
  install (Vue) {
    // HTML of a text built with values, to use with v-html
    Vue.prototype.$sanitizeHtml = sanitizeHtml
  }
}

export default sanitizeHtml
