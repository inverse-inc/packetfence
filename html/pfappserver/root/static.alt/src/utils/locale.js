import Vue from 'vue'
import VueI18n from 'vue-i18n'
import Formatter from './formatter'

Vue.use(VueI18n)

const locale = 'en-US' // default locale
export const formatter = new Formatter({ locale })

const i18n = new VueI18n({
  locale,
  formatter,
  messages: { 'en-US': {} },
  silentTranslationWarn: true, // suppress console warn on missing translations
  missing: (locale, key, vm, values) => {
    // uncomment the next line to debug missing translations
    // console.error(`[Translation] missing: locale=${locale}, key=${key}, values=${JSON.stringify(values)}`)
    if (values === [] || !values[0] || !key.includes('{') || !key.includes('}')) return key
    // handle formatting manually
    try {
      return formatter.interpolate(key, values[0])[0]
    } catch (err) {
      // eslint-disable-next-line
      console.error(err)
    }
    return key
  }
})

export default i18n
