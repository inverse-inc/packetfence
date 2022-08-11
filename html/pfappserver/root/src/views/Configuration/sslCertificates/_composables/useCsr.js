import { computed, customRef, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventJail from '@/composables/useEventJail'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { recomposeRDNSequence, recomposeSAN } from '../config'

const defaults = () => ({ // use function to avoid reactive poisoning of defaults
  country: undefined,
  state: undefined,
  locality: undefined,
  organization_name: undefined,
  common_name: undefined
})

const schema = yup.object({
  country: yup.string().required(i18n.t('Country required.')),
  state: yup.string().required(i18n.t('State required.')),
  locality: yup.string().required(i18n.t('Locality required.')),
  organization_name: yup.string().required(i18n.t('Organization name required.')),
  common_name: yup.string().required(i18n.t('Common name required.'))
})

const useCsrProps = {
  id: {
    type: String
  },
  certificate: {
    type: Object
  },
  value: { // v-model: show/hide
    type: Boolean
  }
}

const useCsr = (props, context) => {

  const { root: { $store } = {}, emit, refs } = context

  const {
    id,
    certificate,
    value,
  } = toRefs(props)

  const title = computed(() => i18n.t('Generate Signing Request for {certificate} certificate', { certificate: id.value.toUpperCase() }))
  const csr = ref(undefined)
  const csrRef = ref(null)

  const form = ref(defaults())
  watch(certificate, () => {
    const { Subject = '', ['Subject Alternative Names']: SubjectAlternativeNames = [] } = certificate.value
    form.value = { ...form.value, ...recomposeRDNSequence(Subject), ...recomposeSAN(SubjectAlternativeNames) }
  }, { immediate: true })

  const formRef = ref(null)
  useEventJail(formRef)
  const isLoading = computed(() => $store.getters['$_certificates/isLoading'])

  const isValid = useDebouncedWatchHandler(form, () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))

  const onGenerate = () => $store.dispatch('$_certificates/generateCertificateSigningRequest', { ...form.value, id: id.value }).then(_csr => {
    csr.value = _csr
  })

  const onClipboard = () => {
    if (document.queryCommandSupported('copy')) {
      refs.csrRef.$el.select()
      document.execCommand('copy')
      $store.dispatch('notification/info', { message: i18n.t('Signing Request copied to clipboard') })
    }
  }

  const show = customRef((track, trigger) => ({ // use v-model
    get() {
      track()
      return value.value
    },
    set(newValue) {
      emit('input', newValue)
      trigger()
    }
  }))

  const reset = () => {
    const { Subject = '', ['Subject Alternative Names']: SubjectAlternativeNames = [] } = certificate.value
    form.value = { ...defaults(), ...recomposeRDNSequence(Subject), ...recomposeSAN(SubjectAlternativeNames) } // reset form when shown/hidden
    csr.value = undefined
  }

  const onHide = () => {
    show.value = false
  }

  return {
    title,
    csr,
    csrRef,
    form,
    formRef,
    schema,
    isLoading,
    isValid,
    onGenerate,
    onClipboard,

    show,
    reset,
    onHide
  }
}

export {
  useCsrProps,
  useCsr
}
