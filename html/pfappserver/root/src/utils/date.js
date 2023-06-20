import i18n from '@/utils/locale'
import { formatInTimeZone, zonedTimeToUtc } from 'date-fns-tz'

export const isoDateFormat = 'yyyy-MM-dd'

export const isoDateMax = '9999-12-12'

export const isoTimeFormat = 'HH:mm:ss'

export const isoTimeMax = '23:59:59'

export const isoDateTimeFormat = `${isoDateFormat} ${isoTimeFormat}`

export const isoDateTimeMax = `${isoDateMax} ${isoTimeMax}`

export const isoDateTimeZeroFormat = isoDateTimeFormat.replace(/[0-9]/g,'0')

export const isoDateTimeFormatTz = `${isoDateFormat} ${isoTimeFormat} zzz`

export const toUtc = (date, fromZone) => zonedTimeToUtc(date, fromZone)

export const offsetFormat = (date, fromZone, toZone, _format = isoDateTimeFormat) => formatInTimeZone(toUtc(date, fromZone), toZone, _format)

export const offsetFormatTz = (date, fromZone, toZone, _format = isoDateTimeFormatTz) => formatInTimeZone(toUtc(date, fromZone), toZone, _format)

export const offsetLocale = (date, fromZone, toZone, locale = i18n.locale) => new Date(offsetFormat(date, fromZone, toZone)).toLocaleString(locale)