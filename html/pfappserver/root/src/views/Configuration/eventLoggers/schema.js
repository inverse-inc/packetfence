import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'eventLoggerIdExistsExcept', function (exceptId = '', message) {
  return this.test({
    name: 'eventLoggerIdExistsExcept',
    message: message || i18n.t('Identifier exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptId.toLowerCase()) return true
      return store.dispatch('config/getEventLoggers').then(response => {
        return response.filter(eventLogger => eventLogger.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

export const schema = (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Identifer required.'))
      .eventLoggerIdExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Identifier exists.')),
    description: yup.string().nullable().label(i18n.t('Description'))
      .required(i18n.t('Description required.')),
    host: yup.string().nullable().label(i18n.t('Host'))
      .required(i18n.t('Host required.')),
    port: yup.string().nullable().label(i18n.t('Port')),
    facility: yup.string().nullable().label(i18n.t('Facility'))
      .required(i18n.t('Facility required.')),
    namespaces: yup.array().ensure().label(i18n.t('Namespaces')),
    priority: yup.string().nullable().label(i18n.t('Priority'))
  })
}

export default schema
