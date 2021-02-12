import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    user: yup.string().nullable(),
    pass: yup.string().nullable()
  })
}

export default schema

