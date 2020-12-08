import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export default (props) => {
  const {
    id
  } = props

  return yup.object().shape({
    id: yup.string().nullable()
  })
}
