import yup from '@/utils/yup'

export default () => {
  return yup.object().shape({
    id: yup.string().nullable()
  })
}
