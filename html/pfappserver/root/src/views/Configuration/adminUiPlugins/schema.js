import i18n from '@/utils/locale'
import yup from '@/utils/yup'

yup.addMethod(yup.string, 'isJsonObject', function (message) {
  return this.test({
    name: 'isJsonObject',
    message: message || i18n.t('Invalid JSON object.'),
    test: (value) => {
      if (!value) return true
      try {
        const json = JSON.parse(value)
        return json !== null && typeof json === 'object' && !Array.isArray(json)
      } catch (e) {
        return false
      }
    }
  })
})

export const schema = () => {
  return yup.object({
    id: yup.string()
      .nullable()
      .required(i18n.t('Plugin required.'))
      .matches(/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/, i18n.t('Only letters, digits, underscores and dashes.')),
    upstream: yup.string()
      .nullable()
      .required(i18n.t('Upstream required.'))
      .matches(/^https?:\/\/[^/\s]+(\/\S*)?$/, i18n.t('Invalid http or https URL.')),
    manifest: yup.string().nullable().isJsonObject(),
    config_files: yup.array().ensure().of(
      yup.string()
        .nullable()
        .matches(/^[a-zA-Z0-9_.-]+\.conf:config::[a-zA-Z0-9_:]+$/, i18n.t('Use <file>.conf:<pfconfig namespace>.'))
    )
  })
}

export default schema
