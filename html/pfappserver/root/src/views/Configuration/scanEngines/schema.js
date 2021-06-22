import store from '@/store'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'scanEngineIdentifierNotExistsExcept', function (exceptName = '', message) {
  return this.test({
    name: 'scanEngineIdentifierNotExistsExcept',
    message: message || i18n.t('Name exists.'),
    test: (value) => {
      if (!value || value.toLowerCase() === exceptName.toLowerCase()) return true
      return store.dispatch('config/getScans').then(response => {
        return response.filter(scan => scan.id.toLowerCase() === value.toLowerCase()).length === 0
      }).catch(() => {
        return true
      })
    }
  })
})

const schemaCategory = yup.string().nullable().label(i18n.t('Category'))

const schemaCategories = yup.array().ensure().of(schemaCategory)

const schemaOs = yup.string().nullable().label('OS')

const schemaOses = yup.array().ensure().of(schemaOs)

export default (props) => {
  const {
    id,
    isNew,
    isClone
  } = props

  return yup.object().shape({
    id: yup.string().label(i18n.t('Name'))
      .nullable()
      .scanEngineIdentifierNotExistsExcept((!isNew && !isClone) ? id : undefined, i18n.t('Name exists.')),
    categories: schemaCategories,
    domain: yup.string().nullable().label(i18n.t('Domain')),
    engine_id: yup.string().nullable().label(i18n.t('Engine')),
    ip: yup.string().nullable().label(i18n.t('IP')),
    nessus_clientpolicy: yup.string().nullable().label(i18n.t('Policy')),
    openvas_alertid: yup.string().nullable().label('ID'),
    openvas_configid: yup.string().nullable().label('ID'),
    openvas_reportformatid: yup.string().nullable().label('ID'),
    oses: schemaOses,
    password: yup.string().nullable().label(i18n.t('Password')),
    port: yup.string().nullable().label(i18n.t('Port')),
    scannername: yup.string().nullable().label(i18n.t('Name')),
    site_id: yup.string().nullable().label(i18n.t('Site')),
    template_id: yup.string().nullable().label(i18n.t('Template')),
    username: yup.string().nullable().label(i18n.t('Username'))
  })
}
