import i18n from '@/utils/locale'
import pfFieldAccessDuration from '@/components/pfFieldAccessDuration'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'

export const pfConfigurationAccessDurationSerialize = (arr = []) => {
  return arr.map(duration => {
    if (!duration) return
    const {
      interval = '',
      unit = '',
      base = '',
      extendedInterval = '',
      extendedUnit = ''
    } = duration
    let str = interval + unit
    if (base && extendedInterval && extendedUnit) {
      str += base
      str += ((extendedInterval >= 0) ? '+' : '') + extendedInterval // add leading '+'
      str += extendedUnit
    }
    return str
  }).join(',')
}

export const pfConfigurationAccessDurationDeserialize = (csv = '') => {
  return csv.split(',').map((duration) => {
    // destructure duration using regular expression
    const [
      _, // ignore
      interval, // \d+
      unit, // [smhDWMY]{1}
      base, // [FR]
      __, // ignore
      extendedInterval, // [+-]\d+
      extendedUnit // [smhDWMY]{1}
    ] = duration.match(/(\d+)([smhDWMY]){1}([FR])?(([+-]\d+)([smhDWMY]){1})?/)
    return {
      interval: interval,
      unit: unit,
      base: base,
      extendedInterval: (~~extendedInterval !== 0)
        ? ~~extendedInterval.toString() // drop leading '+'
        : undefined,
      extendedUnit: extendedUnit
    }
  })
}

export const pfConfigurationAccessDurationViewFields = (context = {}) => {
  const {
    form,
    placeholders
  } = context
  return [
    {
      tab: null,
      fields: [
        {
          label: i18n.t('Access duration choices'),
          text: i18n.t('List of all the choices offered in the access duration action of an authentication source.'),
          fields: [
            {
              key: 'access_duration_choices',
              component: pfFormFields,
              attrs: {
                buttonLabel: 'Add Access Duration',
                sortable: true,
                field: {
                  component: pfFieldAccessDuration
                },
                invalidFeedback: [
                  { [i18n.t('Access Duration(s) contain one or more errors.')]: true }
                ]
              }
            }
          ]
        },
        {
          label: i18n.t('Default access duration'),
          text: i18n.t('This is the default access duration value selected in the dropdown. The value must be part of the above list of access duration choices.'),
          fields: [
            {
              key: 'default_access_duration',
              component: pfFormChosen,
              attrs: {
                placeholder: i18n.t('Choose Access Duration (default: "{default}")', { default: placeholders.default_access_duration }),
                collapseObject: true,
                trackBy: 'value',
                label: 'text',
                options: ('access_duration_choices' in form && form.access_duration_choices) // could be undefined or null
                  ? form.access_duration_choices.map(duration => {
                    const strDuration = pfConfigurationAccessDurationSerialize([duration])
                    return { text: strDuration, value: strDuration }
                  })
                  : []
              }
            }
          ]
        }
      ]
    }
  ]
}

export const pfConfigurationAccessDurationViewDefaults = (context = {}) => {
  return {}
}

export const pfConfigurationAccessDurationViewPlaceholders = (context = {}) => {
  return {
    default_access_duration: '12h'
  }
}
