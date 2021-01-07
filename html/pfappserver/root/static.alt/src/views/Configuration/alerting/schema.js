import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    emailaddr: yup.string().isEmailCsv(),
    fromaddr: yup.string().nullable().email(),
    smtp_port: yup.string().nullable().isPort(),
    test_emailaddr: yup.string().isEmailCsv()
  })
}

export default schema
