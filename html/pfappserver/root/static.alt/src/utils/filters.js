import i18n from '@/utils/locale'
import { parse, format, distanceInWordsToNow } from 'date-fns'

const filters = {
  longDateTime (value) {
    if (!value) {
      return ''
    } else if (value === '0000-00-00 00:00:00') {
      return i18n.t('Never')
    } else {
      let localeObject, localeFormat
      if (i18n.locale === 'fr') {
        localeObject = require('date-fns/locale/fr')
        localeFormat = 'dddd, D MMMM, YYYY, HH:mm:ss'
      } else {
        localeObject = require('date-fns/locale/en')
        localeFormat = 'dddd, MMMM D, YYYY, hh:mm:ss a'
      }
      return format(parse(value), localeFormat, { locale: localeObject })
    }
  },
  shortDateTime (value) {
    if (!value) {
      return ''
    } else if (value === '0000-00-00 00:00:00') {
      return i18n.t('Never')
    } else {
      let localeObject, localeFormat
      if (i18n.locale === 'fr') {
        localeObject = require('date-fns/locale/fr')
        localeFormat = 'DD/MM/YY HH:mm'
      } else {
        localeObject = require('date-fns/locale/en')
        localeFormat = 'MM/DD/YY hh:mm a'
      }
      return format(parse(value), localeFormat, { locale: localeObject })
    }
  },
  relativeDate (value) {
    if (!value) {
      return ''
    } else if (value === '0000-00-00 00:00:00') {
      return i18n.t('Never')
    } else {
      let localeObject
      if (i18n.locale === 'fr') {
        localeObject = require('date-fns/locale/fr')
      } else {
        localeObject = require('date-fns/locale/en')
      }
      return distanceInWordsToNow(parse(value), { locale: localeObject })
    }
  }
}

export default filters
