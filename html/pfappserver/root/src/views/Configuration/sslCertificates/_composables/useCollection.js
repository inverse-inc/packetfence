import { computed, toRefs } from '@vue/composition-api'
import i18n from '@/utils/locale'

export const useItemTitle = (props) => {
  const {
    id
  } = toRefs(props)
  return computed(() => id.value.toUpperCase())
}

export const useStore = (props, context, form) => {
  const {
    id
  } = toRefs(props)
  const { root: { $store } = {} } = context

  const getItem = () => $store.dispatch('$_certificates/getCertificate', id.value).then(_certificate => {
    const { status, ...certificate } = _certificate // strip out `status` from response
    return $store.dispatch('$_certificates/getCertificateInfo', id.value).then(_info => {
      const { status, ...info } = { ..._info, common_name: '' } // strip out `status` from response
      return { certificate: { ...certificate, check_chain: 'enabled' }, info }
    })
  })

  return {
    isLoading: computed(() => $store.getters['$_certificates/isLoading']),
    getItem,
    updateItem: () => {
      const {
        id
      } = toRefs(props)
      const { certificate, certificate: { intermediate_cas = [], lets_encrypt } = {} } = form.value
      if (intermediate_cas.length === 0) // omit intermediate_cas when empty []
        certificate.intermediate_cas = undefined
      let creationPromise
      if (lets_encrypt)
        creationPromise = $store.dispatch('$_certificates/createLetsEncryptCertificate', certificate)
      else
        creationPromise = $store.dispatch('$_certificates/createCertificate', certificate)
      return creationPromise.then(() => {
        $store.dispatch('notification/info', { message: i18n.t('{certificate} certificate saved', { certificate: id.value.toUpperCase() }) })
        getItem().then(item => form.value = item)
      }).finally(() =>
        window.scrollTo(0, 0)
      )
    }
  }
}
