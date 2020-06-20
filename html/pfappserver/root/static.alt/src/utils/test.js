/*
 * Helpers for @vue/test-utils, vue-jest
 *
 * resources:
 *    https://vue-test-utils.vuejs.org/
 *    https://webdevetc.com/blog/vue-test-utils-advanced-features
*/
import { mount, shallowMount, createLocalVue } from '@vue/test-utils'
import VueI18n from 'vue-i18n'

export const factory = (component, config) => {
  // mock vue-i18n
  let localVue = createLocalVue()
  localVue.use(VueI18n)
  const i18n = new VueI18n({
    locale: 'en',
    messages: {/* undef, fallback to missing */},
    missing: (locale, key) => (locale === 'en')
      ? key
      : key.split('').reverse().join('') // reverse
  })
  return mount(component, { i18n, localVue, ...config })
}

export const shallowFactory = (component, config) => {
  return shallowMount(component, config)
}

