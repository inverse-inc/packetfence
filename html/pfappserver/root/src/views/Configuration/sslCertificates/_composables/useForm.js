import { computed, ref, toRefs, watch } from '@vue/composition-api'
import useEventActionKey from '@/composables/useEventActionKey'
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

const useForm = (form, props, context) => {

  const {
    id
  } = toRefs(props)

  const { emit } = context

  const actionKey = useEventActionKey()

  const schema = computed(() => schemaFn(props))

  const title = computed(() => id.value.toUpperCase())

  const isCertificationAuthority = computed(() => {
    const { info: { ca } = {} } = form.value
    return ca
  })

  const isCertKeyMatch = computed(() => {
    const { info: { cert_key_match: { success } = {} } = {} } = form.value
    emit('cert-key-match', success)
    return success
  })

  const isChainValid = computed(() => {
    const { info: { chain_is_valid: { success } = {} } = {} } = form.value
    emit('chain-valid', success)
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
  const certificationAuthorityLocale = computed(() => {
    const { info: { ca = [] } = {} } = form.value
    return ca.map((_ca, _i) => {
      return Object.keys(_ca).reduce((stack, key) => {
        return (key in strings)
          ? { ...stack, [i18n.t(strings[key])]: form.value.info.ca[_i][key] }
          : { ...stack, [key]: form.value.info.ca[_i][key] }
      }, {})      
    })
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

  const services = computed(() => certificateServices[id.value] || [])

  // cosmetic props only
  const isFindIntermediateCas = ref(false)

  watch(isFindIntermediateCas, isFindIntermediateCas => {
    if (isFindIntermediateCas && 'certificate' in form.value) // clear intermediate CAs
      form.value.certificate.intermediate_cas = []
  })

  watch([form], () => {
    const { certificate: { intermediate_cas = [] } = {} } = form.value || {}
      isFindIntermediateCas.value = (intermediate_cas.length === 0)
  }, { deep: true, immediate: true })

  return {
    actionKey,
    schema,
    certificateLocale,
    certificationAuthorityLocale,
    title,
    services,

    isShowEdit,
    doShowEdit,
    doHideEdit,

    isShowCsr,
    doShowCsr,
    doHideCsr,

    isCertificationAuthority,
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
