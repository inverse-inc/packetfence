/**
 * HTML of the texts built with values (names, IDs, messages) that are
 * rendered with v-html: only the formatting elements and attributes are kept.
 *
 * The HTML is parsed with DOMParser (the scripts of the parsed document are not
 * run, its resources are not loaded). Then:
 * - the elements of DROPPED_TAGS are removed with their content;
 * - the elements not in ALLOWED_TAGS are replaced with their content;
 * - only the attributes of ALLOWED_ATTRIBUTES are kept, href only with an
 *   http, https or mailto URL or a relative URL.
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

const sanitizeChildren = (parent, document) => {
  Array.from(parent.childNodes).forEach(node => {
    if (node.nodeType === 3) { // text
      return
    }
    if (node.nodeType !== 1) { // comments, processing instructions...
      parent.removeChild(node)
      return
    }
    const tag = node.tagName.toLowerCase()
    if (DROPPED_TAGS.has(tag)) {
      parent.removeChild(node)
      return
    }
    sanitizeChildren(node, document)
    if (!ALLOWED_TAGS.has(tag)) {
      const fragment = document.createDocumentFragment()
      while (node.firstChild) {
        fragment.appendChild(node.firstChild)
      }
      parent.replaceChild(fragment, node)
      return
    }
    Array.from(node.attributes).forEach(({ name, value }) => {
      if (!isAllowedAttribute(tag, name.toLowerCase(), value)) {
        node.removeAttribute(name)
      }
    })
    if (tag === 'a' && node.getAttribute('target') === '_blank') {
      node.setAttribute('rel', 'noopener noreferrer')
    }
  })
}

export const sanitizeHtml = (html) => {
  if (html === undefined || html === null || html === '') {
    return ''
  }
  const document = new DOMParser().parseFromString(`<!DOCTYPE html><html><body>${html}</body></html>`, 'text/html')
  sanitizeChildren(document.body, document)
  return document.body.innerHTML
}

export const pfSanitizeHtmlPlugin = {
  install (Vue) {
    // HTML of a text built with values, to use with v-html
    Vue.prototype.$sanitizeHtml = sanitizeHtml
  }
}

export default sanitizeHtml
