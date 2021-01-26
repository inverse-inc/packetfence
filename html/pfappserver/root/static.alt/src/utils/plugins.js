export const pfTemplatePlugin = {
  install (Vue) {
    Vue.prototype.$strong = (text) => {
      const element = document.createElement('div');
      element.innerText = text;
      return `<strong>${element.innerText}</strong>`
    }
    Vue.prototype.$sanitizedClass = (text) => {
      return text.replace(/[^_a-zA-Z0-9-]/g, '_').replace(/^([0-9])/, '_$1')
    }
  }
}
