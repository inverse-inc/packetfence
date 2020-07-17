import i18n from '@/utils/locale'
import pfFieldAccessDuration from '@/components/pfFieldAccessDuration'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormFields from '@/components/pfFormFields'
import {
  attributesFromMeta,
  validatorsFromMeta
} from './'
import {
  conditional
} from '@/globals/pfValidators'
import {
  required,
  numeric
} from 'vuelidate/lib/validators'
import duration from '@/utils/duration'

export const view = (form = {}, meta = {}) => {
  return [
    {
      tab: null,
      rows: [
        {
          label: i18n.t('Access duration choices'),
          text: i18n.t('List of all the choices offered in the access duration action of an authentication source.'),
          cols: [
            {
              namespace: 'access_duration_choices',
              component: pfFormFields,
              attrs: {
                buttonLabel: i18n.t('Add Access Duration'),
                sortable: true,
                field: {
                  component: pfFieldAccessDuration
                },
                invalidFeedback: i18n.t('Access Duration(s) contain one or more errors.')
              }
            }
          ]
        },
        {
          label: i18n.t('Default access duration'),
          text: i18n.t('This is the default access duration value selected in the dropdown. The value must be part of the above list of access duration choices.'),
          cols: [
            {
              namespace: 'default_access_duration',
              component: pfFormChosen,
              attrs: {
                ...attributesFromMeta(meta, 'default_access_duration'),
                ...{
                  options: ('access_duration_choices' in form && form.access_duration_choices) // could be undefined or null
                    ? form.access_duration_choices.map(_duration => {
                      const strDuration = duration.serialize(_duration)
                      return { text: strDuration, value: strDuration }
                    })
                    : []
                }
              }
            }
          ]
        }
      ]
    }
  ]
}

export const validators = (form = {}, meta = {}) => {
  const {
    access_duration_choices = []
  } = form
  return {
    access_duration_choices: {
      $each: {
        interval: {
          [i18n.t('Required.')]: required,
          [i18n.t('Numbers only.')]: numeric,
          [i18n.t('Duplicate.')]: conditional((value, access_duration) => {
            const { interval: aInterval, unit: aUnit, base: aBase, extendedInterval: aExtendedInterval, extendedUnit: aExtendedUnit } = access_duration || {}
            return access_duration_choices.filter(choice => {
              const { interval: cInterval, unit: cUnit, base: cBase, extendedInterval: cExtendedInterval, extendedUnit: cExtendedUnit } = choice || {}
              return (aInterval === cInterval && aUnit === cUnit && aBase === cBase && aExtendedInterval === cExtendedInterval && aExtendedUnit === cExtendedUnit)
            }).length === 1
          })
        },
        unit: {
          [i18n.t('Required.')]: required
        },
        base: {},
        extendedInterval: {
          [i18n.t('Required.')]: conditional((value, access_duration) => (!access_duration || !access_duration.base || !!value)),
          [i18n.t('Numbers only.')]: numeric
        },
        extendedUnit: {
          [i18n.t('Required.')]: conditional((value, access_duration) => (!access_duration || !access_duration.base || !!value))
        }
      }
    },
    default_access_duration: validatorsFromMeta(meta, 'default_access_duration', i18n.t('Default'))
  }
}
