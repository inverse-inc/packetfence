import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import schemaFn from '../schema'

const useFormProps = {
  form: {
    type: Object
  },
  meta: {
    type: Object
  },
  isNew: {
    type: Boolean,
    default: false
  },
  isClone: {
    type: Boolean,
    default: false
  },
  isLoading: {
    type: Boolean,
    default: false
  },
  id: {
    type: String
  }
}

const useForm = (props) => {

  const {
    form,
    meta
  } = toRefs(props)

  const schema = computed(() => schemaFn(props))

  const metaSchema = computed(() => useFormMetaSchema(meta, schema))

  // mutable form requirements
  const wantsEapType = ref(false)
  const wantsDpsk = ref(false)
  const wantsPasscode = ref(false)
  const wantsServerCertificatePath = ref(false)
  const wantsServerRadiusCaPath = ref(false)
  const wantsPkiProvider = ref(false)

  watch(form, () => {
    const { security_type, eap_type } = form.value
    wantsEapType.value = (security_type === 'WPA2')
    wantsDpsk.value = (['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
    wantsPasscode.value = (['WEP', 'WPA'].includes(security_type) || (security_type === 'WPA2' && !eap_type))
    wantsServerCertificatePath.value = (security_type === 'WPA2' && +eap_type === 25) // PEAP
    wantsServerRadiusCaPath.value = (security_type === 'WPA2' && +eap_type === 25) // PEAP
    wantsPkiProvider.value = (security_type === 'WPA2' && +eap_type === 13) // EAP-TLS
  }, { immediate: true, deep: true })

  return {
    schema: metaSchema,

    wantsEapType,
    wantsDpsk,
    wantsPasscode,
    wantsServerCertificatePath,
    wantsServerRadiusCaPath,
    wantsPkiProvider
  }
}

export {
  useFormProps,
  useForm
}
