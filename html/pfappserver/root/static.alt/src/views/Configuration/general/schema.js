import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    domain: yup.string().nullable(),
    hostname: yup.string().nullable(),
    dhcpservers: yup.string().nullable(),
    timezone: yup.string().nullable()
  })
}

export default schema

