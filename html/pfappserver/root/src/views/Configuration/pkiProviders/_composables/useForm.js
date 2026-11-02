import { computed, toRefs } from '@vue/composition-api'
import { useFormMetaSchema } from '@/composables/useMeta'
import schemaFn from '../schema'
import i18n from '@/utils/locale'
import PkiStoreModule from '../../pki/_store'
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

const useForm = (props, context) => {

  const {
    form,
    meta
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const schema = computed(() => schemaFn(props))

  const metaSchema = computed(() => useFormMetaSchema(meta, schema))

  const onPkiImportServerCertificate = ({ certificate, ca }) => {
    setUploadPem(form.value, 'server_cert_path', certificate)
    // also provide the CA which signed the server certificate unless one is already set
    const { ca_cert_path, ca_cert_path_upload } = form.value
    if (!ca_cert_path && !ca_cert_path_upload)
      setUploadPem(form.value, 'ca_cert_path', ca)
  }

  const onPkiImportCa = ({ ca }) => setUploadPem(form.value, 'ca_cert_path', ca)

  // use the CA of the pfpki template (profile) used by the provider
  const onPkiImportTemplateCa = () => {
    if (!$store.state.$_pkis)
      $store.registerModule('$_pkis', PkiStoreModule)
    return $store.dispatch('$_pkis/getProfile', form.value.profile)
      .then(profile => $store.dispatch('$_pkis/getCa', profile.ca_id))
      .then(ca => {
        setUploadPem(form.value, 'ca_cert_path', ca.cert)
        $store.dispatch('notification/info', { message: i18n.t('Imported {name}, save to apply.', { name: ca.cn }) })
      })
  }

  return {
    schema: metaSchema,
    onPkiImportServerCertificate,
    onPkiImportCa,
    onPkiImportTemplateCa
  }
}

export {
  useFormProps,
  useForm
}
