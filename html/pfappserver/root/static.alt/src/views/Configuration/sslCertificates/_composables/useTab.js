import { computed, toRefs, watch } from '@vue/composition-api'
import { useView as useBaseView, useViewProps as useBaseViewProps } from '@/composables/useView'

const useTabProps = {
  ...useBaseViewProps,

  id: {
    type: String
  }
}

const useTab = (props, context) => {

  const {
    id
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring
  const { root: { $store } = {} } = context

  const {
    rootRef,
    form
  } = useBaseView(props, context)

  const isLoading = computed(() => $store.getters['$_certificates/isLoading'])

  const isCertKeyMatch = computed(() => {
    const { info: { cert_key_match: { success } = {} } = {} } = form.value
    return success
  })

  const isChainValid = computed(() => {
    const { info: { chain_is_valid: { success } = {} } = {} } = form.value
    return success
  })

  const doInit = () => {
    form.value = {
      certificate: {},
      info: { common_name: '', check_chain: 'enabled', lets_encrypt: false }
    }
    // load syncronous
    $store.dispatch('$_certificates/getCertificateInfo', id.value).then(info => {
      const { status, ...rest } = info // strip out `status` from response
      form.value.info = { ...form.value.info, ...rest }
    })
    $store.dispatch('$_certificates/getCertificate', id.value).then(certificate => {
      const { status, ...rest } = certificate // strip out `status` from response
      form.value.certificate = { ...form.value.certificate, ...rest }
    })
  }

  const doReset = doInit

  const doSave = () => {
    $store.dispatch('$_sources/updateAuthenticationSource', form.value).then(() => {
      // noop
    })
  }

  watch(props, () => doInit(), { deep: true, immediate: true })

  return {
    rootRef,

    form,

    isLoading,
    isCertKeyMatch,
    isChainValid,

    doInit,
    doReset,
    doSave
  }
}

export {
  useTabProps,
  useTab
}
