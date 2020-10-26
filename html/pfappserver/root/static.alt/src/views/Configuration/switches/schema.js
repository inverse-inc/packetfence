import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'switchIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'switchIdNotExistsExcept',
    message: message || i18n.t('Source exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getSwitches').then(response => {
        return response.filter(switche => switche.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const inlineTrigger = yup.object({
  type: yup.string().nullable().required(i18n.t('Type required.')),
  value: yup.string()
    .when('type', {
      is: 'always',
      then: yup.string().nullable(),
      otherwise: yup.string().nullable().required(i18n.t('Value required.')),
    })
})

const inlineTriggers = yup.array().of(inlineTrigger)

export const schema = (props) => {
  const {
    isNew,
    isClone,
    id,
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifier required.'))
      .switchIdNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),

    inlineTrigger: inlineTriggers.meta({ invalidFeedback: i18n.t('Inline conditions contains one or more errors.') })
  })
}

export default schema
