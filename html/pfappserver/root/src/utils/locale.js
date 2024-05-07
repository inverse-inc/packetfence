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

// available languages
// first item is default
// labels are in English
// static definition is less resource-intensive than consuming /api/v1/translations
export const languages = [
  {
    locale: 'en',
    label: 'English' // i18n defer
  },
  {
    locale: 'fr',
    label: 'French' // i18n defer
  },
]

export const locales = { // translations /conf/locale/*
  'de': i18n.t('German'),
  'en': i18n.t('English'),
  'es': i18n.t('Spanish'),
  'fr': i18n.t('French'),
  'he_IL': i18n.t('Hebrew'),
  'it': i18n.t('Italian'),
  'nb_NO': i18n.t('Norwegian'),
  'nl': i18n.t('Dutch'),
  'pl_PL': i18n.t('Polish'),
  'pt_BR': i18n.t('Portuguese')
}

export const localesSorted = Object.entries(locales)
  .map(([key, value]) => ({key, value}))
  .sort((a, b) => a.value.localeCompare(b.value))
