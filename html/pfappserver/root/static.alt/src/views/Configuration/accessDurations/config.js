import i18n from '@/utils/locale'

export const intervals = {
  s: i18n.t('seconds'),
  m: i18n.t('minutes'),
  h: i18n.t('hours'),
  D: i18n.t('days'),
  W: i18n.t('weeks'),
  M: i18n.t('months'),
  Y: i18n.t('years')
}

export const intervalsOptions = Object.keys(intervals).map(key => ({ value: key, text: intervals[key] }))

const unit2str = (unit, isPlural = false) => {
  const plural = (isPlural) ? 's' : ''
  switch (unit) {
    case 's': return (plural) ? i18n.t('seconds') : i18n.t('second')
    case 'm': return (plural) ? i18n.t('minutes') : i18n.t('minute')
    case 'h': return (plural) ? i18n.t('hours') : i18n.t('hour')
    case 'D': return (plural) ? i18n.t('days') : i18n.t('day')
    case 'W': return (plural) ? i18n.t('weeks') : i18n.t('week')
    case 'M': return (plural) ? i18n.t('months') : i18n.t('month')
    case 'Y': return (plural) ? i18n.t('years') : i18n.t('year')
  }
}

const unit2seconds = (unit) => {
  let seconds = 1
  switch (unit) { // compound seconds w/ fallthrough
    case 'Y': seconds *= 12
      /* falls through */
    case 'M': seconds *= 30.4375 // leap-year
      /* falls through */
    case 'W': seconds *= 7
      /* falls through */
    case 'D': seconds *= 24
      /* falls through */
    case 'h': seconds *= 60
      /* falls through */
    case 'm': seconds *= 60
      /* falls through */
  }
  return seconds
}

export const composeDuration = (value) => {
  const matches = (value || '').match(/(\d+)([smhDWMY]){1}([FR])?(([+-]\d+)([smhDWMY]){1})?/)
  if (!matches)
    return {}
  const [
    // eslint-disable-next-line no-unused-vars
    _, // ignore
    interval, // \d+
    unit, // [smhDWMY]{1}
    base, // [FR]
    // eslint-disable-next-line no-unused-vars
    __, // ignore
    extendedInterval, // [+-]\d+
    extendedUnit // [smhDWMY]{1}
  ] = matches
  let name = `${interval} ${unit2str(unit, Math.abs(interval) !== 1)}`
  if (base && extendedInterval && extendedUnit) {
    let baseStr = ''
    switch (base) {
      case 'F': baseStr = unit2str('D'); break // relative to start of day
      case 'R': baseStr = unit2str(unit); break // relative to start of period (unit)
    }
    name += ` {@${baseStr} ${extendedInterval} ${unit2str(extendedUnit, Math.abs(extendedInterval) !== 1)})`
  }
  // fwd `sort`ing
  const sort = (~~interval * unit2seconds(unit)) + (~~extendedInterval * unit2seconds(extendedUnit))
  return {
    name,
    text: name,
    value,
    sort,
    interval,
    unit,
    base,
    extendedInterval: (~~extendedInterval !== 0)
      ? ~~extendedInterval.toString() // drop leading '+'
      : undefined,
    extendedUnit
  }
}

export const serializeDuration = (object) => {
  const {
    interval = '',
    unit = '',
    base = '',
    extendedInterval = '',
    extendedUnit = ''
  } = object || {}
  let str = interval + unit
  if (base && extendedInterval && extendedUnit) {
    str += base
    str += ((extendedInterval >= 0) ? '+' : '') + extendedInterval // add leading '+'
    str += extendedUnit
  }
  return str
}
