import { computed, ref, toRefs, unref, watch } from '@vue/composition-api'
import { useView as useBaseView, useViewProps as useBaseViewProps } from '@/composables/useView'
import i18n from '@/utils/locale'

const useStoreProps = {
  ...useBaseViewProps,

  id: {
    type: String
  }
}

const useStore = (props, context, form) => {

  const {
    id
  } = toRefs(props) // toRefs maintains reactivity w/ destructuring
  const { root: { $store, $router } = {} } = context

  const isLoading = computed(() => $store.getters['$_certificates/isLoading'])

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
    isLoading,
    doInit,
    doReset,
    doSave
  }
}

export {
  useStoreProps,
  useStore
}
