import i18n from '@/utils/locale'

export const pfOperators = {
  and: i18n.t('ALL (AND)'),
  not_and: i18n.t('NOT ALL (NAND)'),
  or: i18n.t('ANY (OR)'),
  not_or: i18n.t('NONE (NOR)'),
  true: i18n.t('TRUE'),

  contains: i18n.t('contains'),
  not_contains: i18n.t('not contains'),
  includes: i18n.t('includes'),
  not_includes: i18n.t('not includes'),
  defined: i18n.t('defined'),
  not_defined: i18n.t('not defined'),
  starts_with: i18n.t('starts with'),
  not_starts_with: i18n.t('not starts with'),
  ends_with: i18n.t('ends with'),
  not_ends_with: i18n.t('not ends with'),
  equals: i18n.t('equals'),
  not_equals: i18n.t('not equals'),
  regex: i18n.t('matches'),
  not_regex: i18n.t('not matches'),
  fingerbank_device_is_a: i18n.t('Fingerbank device is'),
  not_fingerbank_device_is_a: i18n.t('Fingerbank device is not'),
  date_is_before: i18n.t('date is before'),
  not_date_is_before: i18n.t('date is not before'),
  date_is_after: i18n.t('date is after'),
  not_date_is_after: i18n.t('date is not after'),
  time_period: i18n.t('time period within'),
  not_time_period: i18n.t('time period not within')
}

