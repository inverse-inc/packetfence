import i18n from '@/utils/locale'
import yup from '@/utils/yup'

export const schema = () => {
  return yup.object({
    pfdhcplistener_packet_size: yup.string().nullable().label(i18n.t('Size'))
  })
}

export default schema
