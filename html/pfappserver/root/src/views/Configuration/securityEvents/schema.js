import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { fingerbankNetworkBehaviorPolicyTypes } from './config'

yup.addMethod(yup.string, 'securityEventIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'securityEventIdNotExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSecurityEvents').then(response => {
        return Object.keys(response).filter(item => item.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaTriggerCondition = yup.object({
  type: yup.string().nullable().required(i18n.t('Type required.')),
  value: yup.string()
    .when('type', {
      is: value => !value,
      then: yup.string().nullable(),
      otherwise: yup.string().nullable().required(i18n.t('Value required.'))
    })
})

const schemaTriggerUsage = yup.object({
  type: yup.string().nullable(),
  direction: yup.string()
    .when('type', {
      is: 'bandwidth',
      then: yup.string().nullable().required(i18n.t('Direction required.'))
    }),
  limit: yup.string()
    .when('type', {
      is: 'bandwidth',
      then: yup.string().nullable().required(i18n.t('Limit required.'))
    }),
  interval: yup.string()
    .when('type', {
      is: 'bandwidth',
      then: yup.string().nullable().required(i18n.t('Interval required.'))
    })
})

const schemaTriggerEvent = yup.object({
  typeValue: yup.object({
    type: yup.string().nullable(),
    value: yup.string()
      .when('type', {
        is: value => !value,
        then: yup.string().nullable(),
        otherwise: yup.string().nullable().required(i18n.t('Value required.'))
      }),
    fingerbank_network_behavior_policy: yup.string()
      .when('type', {
        is: value => value === 'internal',
        then: yup.string()
          .when('value', {
            is: value => fingerbankNetworkBehaviorPolicyTypes.includes(value),
            then: yup.string().nullable().required(i18n.t('Policy required.')),
            otherwise: yup.string().nullable()
          }),
        otherwise: yup.string().nullable()
      })
  })
})

const schemaTrigger = yup.object({
  endpoint: yup.object({
    conditions: yup.array().of(schemaTriggerCondition)
  }),
  profiling: yup.object({
    conditions: yup.array().of(schemaTriggerCondition)
  }),
  usage: schemaTriggerUsage,
  event: schemaTriggerEvent
})

const schemaTriggers = yup.array().of(schemaTrigger.meta({ invalidFeedback: i18n.t('Trigger contains one or more errors.') }))

const schemaWhiteListedRole = yup.string().nullable()

const schemaWhiteListedRoles = yup.array().ensure().of(schemaWhiteListedRole)

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Name required.'))
      .securityEventIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),

    triggers: schemaTriggers.meta({ invalidFeedback: i18n.t('Triggers contains one or more errors.') }),
    desc: yup.string().nullable()
      .label(i18n.t('Description')),
    priority: yup.string().nullable().label(i18n.t('Priority')),
    whitelisted_roles: schemaWhiteListedRoles
  })
}

export default schema
