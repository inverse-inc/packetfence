import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export default yup.object().shape({
  id: yup.string()
    .required(i18n.t('Identifier is required.')),

  notes: yup.string()
    .nullable(),

  max_nodes_per_pid: yup.string()
    .nullable()
})
