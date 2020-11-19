import { computed, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import schemaFn from '../schema'
import {
  certificateServices,
  strings
} from '../config'

const useFormProps = {
  id: {
    type: String
  }
}

const useForm = (props, form) => {

  const {
    id
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const title = computed(() => id.value.toUpperCase())

  const isCertificateAuthority = computed(() => {
    const { info: { ca } = {} } = form.value
    return ca
  })

  const isCertKeyMatch = computed(() => {
    const { info: { cert_key_match: { success } = {} } = {} } = form.value
    return success
  })

  const isChainValid = computed(() => {
    const { info: { chain_is_valid: { success } = {} } = {} } = form.value
    return success
  })

  const isLetsEncrypt = computed(() => {
    const { info: { lets_encrypt } = {} } = form.value
    return lets_encrypt
  })

  // translate keys in certificate
  const certificateLocale = computed(() => {
    const { info: { certificate = {} } = {} } = form.value
    return Object.keys(certificate).reduce((stack, key) => {
      return (key in strings)
        ? { ...stack, [i18n.t(strings[key])]: form.value.info.certificate[key] }
        : { ...stack, [key]: form.value.info.certificate[key] }
    }, {})
  })

  // translate keys in certificate
  const certificateAuthorityLocale = computed(() => {
    const { info: { ca = {} } = {} } = form.value
    return Object.keys(ca).reduce((stack, key) => {
      return (key in strings)
        ? { ...stack, [i18n.t(strings[key])]: form.value.info.ca[key] }
        : { ...stack, [key]: form.value.info.ca[key] }
    }, {})
  })

  const isShowEdit = ref(false)
  const doShowEdit = () => {
    isShowEdit.value = true
    window.scrollTo(0, 0)
  }
  const doHideEdit = () => {
    isShowEdit.value = false
  }

  const isShowCsr = ref(false)
  const doShowCsr = () => {
    isShowCsr.value = true
  }
  const doHideCsr = () => {
    isShowCsr.value = false
  }

  const showAlert = ref(true)

  const services = computed(() => certificateServices[id.value] || [])

  // cosmetic props only
  const isFindIntermediateCas = ref(false)

  watch(isFindIntermediateCas, isFindIntermediateCas => {
    if (isFindIntermediateCas) // clear intermediate CAs
      form.value.certificate.intermediate_cas = []
  })

  return {
    schema,
    certificateLocale,
    certificateAuthorityLocale,
    title,

    showAlert,
    services,

    isShowEdit,
    doShowEdit,
    doHideEdit,

    isShowCsr,
    doShowCsr,
    doHideCsr,

    isCertificateAuthority,
    isCertKeyMatch,
    isChainValid,
    isLetsEncrypt,
    isFindIntermediateCas
  }
}

export {
  useFormProps,
  useForm
}
