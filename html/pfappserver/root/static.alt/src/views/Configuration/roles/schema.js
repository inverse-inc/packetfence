import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export default yup.object().shape({
  id: yup.string()
    .nullable()
    .required(i18n.t('Name required.')),

  notes: yup.string()
    .nullable(),

  max_nodes_per_pid: yup.string()
    .nullable()
})
