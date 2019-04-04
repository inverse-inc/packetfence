export const pfTemplatePlugin = {
  install (Vue) {
    Vue.prototype.$strong = (text) => {
      return `<strong>${text}</strong>`
    }
  }
}
