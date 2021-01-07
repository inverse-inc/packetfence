import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'switchIdNotExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'switchIdNotExistsExcept',
    message: message || i18n.t('Switch exists.'),
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

const schemaInlineTrigger = yup.object({
  type: yup.string().nullable().required(i18n.t('Type required.')),
  value: yup.string()
    .when('type', type => ((!type || type === 'always')
      ? yup.string().nullable()
      : yup.string().nullable().required(i18n.t('Value required.'))
    ))
})

export const schemaInlineTriggers = yup.array().ensure().unique(i18n.t('Duplicate condition.')).of(schemaInlineTrigger)

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

    inlineTrigger: schemaInlineTriggers
  })
}

export default schema
