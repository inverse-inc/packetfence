import Vue from 'vue'
import VueI18n from 'vue-i18n'

Vue.use(VueI18n)

const i18n = new VueI18n({
  locale: 'en',
  messages: { en: {} },
  missing: (locale, key) => {
    console.debug(`[Translation] missing: locale=${locale}, key=${key}`)
  }
})

export default i18n
