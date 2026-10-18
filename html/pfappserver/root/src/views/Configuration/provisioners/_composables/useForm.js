import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import schemaFn from '../schema'
import { setUploadPem } from '../../pki/_composables/usePkiImport'

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

  const onPkiImportServerCertificate = ({ certificate, ca }) => {
    setUploadPem(form.value, 'server_certificate_path', certificate)
    // also provide the CA which signed the server certificate unless one is already set
    const { ca_cert_path, ca_cert_path_upload } = form.value
    if (!ca_cert_path && !ca_cert_path_upload)
      setUploadPem(form.value, 'ca_cert_path', ca)
  }

  const onPkiImportCa = ({ ca }) => setUploadPem(form.value, 'ca_cert_path', ca)

  return {
    schema: metaSchema,

    wantsEapType,
    wantsDpsk,
    wantsPasscode,
    wantsServerCertificatePath,
    wantsServerRadiusCaPath,
    wantsPkiProvider,
    onPkiImportServerCertificate,
    onPkiImportCa
  }
}

export {
  useFormProps,
  useForm
}
