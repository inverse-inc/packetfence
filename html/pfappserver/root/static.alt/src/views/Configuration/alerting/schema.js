import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    emailaddr: yup.string().isEmailCsv(),
    fromaddr: yup.string().email(),
    smtp_port: yup.string().isPort(),
    test_emailaddr: yup.string().isEmailCsv()
  })
}

export default schema
