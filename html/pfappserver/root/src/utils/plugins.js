import escape from 'lodash/escape'

export const pfTemplatePlugin = {
  install (Vue) {
    // HTML of a text in bold, to use with v-html
    Vue.prototype.$strong = (text) => {
      return `<strong>${escape(text)}</strong>`
    }
    Vue.prototype.$sanitizedClass = (text) => {
      return text.replace(/[^_a-zA-Z0-9-]/g, '_').replace(/^([0-9])/, '_$1')
    }
  }
}
