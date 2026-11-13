<template>
  <div v-if="isServiceAlive" class="d-flex align-items-center">
    <b-button :size="size" variant="outline-primary" :disabled="disabled" @click="show = true">
      <icon name="download" class="mr-1" /> {{ buttonText || $t('Import from PacketFence PKI') }}
    </b-button>
    <small v-if="imported" class="text-success ml-2">
      <icon name="check" class="mr-1" /> {{ imported }}
    </small>

    <b-modal v-model="show"
      @shown="reset"
      size="lg"
      :title="modalTitle || $t('Import from PacketFence PKI')"
    >
      <b-form @submit.prevent="onImport" ref="formRef">
        <base-form
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <base-form-group-chosen-one v-if="modeOptions.length > 1"
            namespace="mode"
            :column-label="$t('Source')"
            :options="modeOptions"
          />

          <template v-if="form.mode === 'cert' || form.mode === 'public'">
            <base-form-group-chosen-one namespace="cert_id"
              :column-label="$t('Certificate')"
              :options="certOptions"
              :text="(form.mode === 'cert') ? $t('Only certificates with their private key stored in the PKI are listed.') : undefined"
            />
          </template>

          <template v-if="form.mode === 'csr'">
            <base-form-group-chosen-one-profile namespace="profile_id"
              :column-label="$t('Template')"
              :text="$t('The template should allow the Server Authentication extended key usage. The current private key is kept, only the certificate is replaced.')"
            />
            <base-form-group-chosen-country namespace="country"
              :column-label="$t('Country')"
            />
            <base-form-group-input namespace="state"
              :column-label="$t('State')"
            />
            <base-form-group-input namespace="locality"
              :column-label="$t('Locality')"
            />
            <base-form-group-input namespace="organization_name"
              :column-label="$t('Organization Name')"
            />
            <base-form-group-input namespace="common_name"
              :column-label="$t('Common Name')"
            />
            <base-form-group-input namespace="subject_alt_names"
              :column-label="$t('Subject Alternative Names (DNS only)')"
              :text="$t('Comma-delimited list of DNS names who should be added as Subject Alternative Names. When left empty, the common name will be used.')"
            />
          </template>

          <template v-if="form.mode === 'ca'">
            <base-form-group-chosen-one-ca namespace="ca_id"
              :column-label="$t('Certificate Authority')"
            />
          </template>
        </base-form>
      </b-form>
      <template v-slot:modal-footer>
        <b-button class="mr-1" variant="secondary" @click="show = false">{{ $t('Close') }}</b-button>
        <b-button variant="primary" :disabled="!isValid || isLoading" @click="onImport">
          <icon v-if="isLoading" name="circle-notch" spin class="mr-1" /> {{ $t('Import') }}
        </b-button>
      </template>
    </b-modal>
  </div>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupChosenCountry,
  BaseFormGroupChosenOne,
  BaseFormGroupInput
} from '@/components/new/'
import BaseFormGroupChosenOneCa from '../cas/_components/BaseFormGroupChosenOneCa'
import BaseFormGroupChosenOneProfile from '../profiles/_components/BaseFormGroupChosenOneProfile'

const components = {
  BaseForm,
  BaseFormGroupChosenCountry,
  BaseFormGroupChosenOne,
  BaseFormGroupChosenOneCa,
  BaseFormGroupChosenOneProfile,
  BaseFormGroupInput
}

const props = {
  // any of: cert (certificate + private key + CA), csr (sign the current private key), ca (CA certificate), public (certificate only)
  modes: {
    type: Array,
    default: () => (['cert', 'csr'])
  },
  // current private key, required by the csr mode
  privateKey: {
    type: String
  },
  buttonText: {
    type: String
  },
  modalTitle: {
    type: String
  },
  size: {
    type: String,
    default: 'sm'
  },
  disabled: {
    type: Boolean
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import useEventJail from '@/composables/useEventJail'
import apiCall from '@/utils/api'
import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import StoreModule from '../_store'

const modeLabels = {
  cert: i18n.t('Existing certificate with its private key'),
  csr: i18n.t('Sign the current private key with a template'),
  ca: i18n.t('Certificate Authority'),
  public: i18n.t('Existing certificate')
}

// fields are only rendered (thus validated) for their own mode
const schema = yup.object({
  mode: yup.string().nullable().required(i18n.t('Source required.')),
  cert_id: yup.string().nullable().required(i18n.t('Certificate required.')),
  ca_id: yup.string().nullable().required(i18n.t('Certificate Authority required.')),
  profile_id: yup.string().nullable().required(i18n.t('Template required.')),
  country: yup.string().nullable().required(i18n.t('Country required.')),
  state: yup.string().nullable().required(i18n.t('State required.')),
  locality: yup.string().nullable().required(i18n.t('Locality required.')),
  organization_name: yup.string().nullable().required(i18n.t('Organization name required.')),
  common_name: yup.string().nullable().required(i18n.t('Common name required.')),
  subject_alt_names: yup.string().nullable()
})

const setup = (props, context) => {

  const {
    modes,
    privateKey
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const isServiceAlive = computed(() => {
    if ($store.getters['system/isSaas']) {
      const { pfpki: { available = false } = {} } = $store.getters['k8s/services']
      return available
    }
    else if ($store.getters['cluster/servicesByServer']) {
      const { pfpki: { hasAlive = false } = {} } = $store.getters['cluster/servicesByServer']
      return hasAlive
    }
    return false
  })
  if (!$store.getters['system/isSaas'])
    $store.dispatch('cluster/getServiceCluster', 'pfpki')

  const modeOptions = computed(() => modes.value
    .filter(mode => mode !== 'csr' || privateKey.value)
    .map(mode => ({ value: mode, text: modeLabels[mode] }))
  )

  const show = ref(false)
  const imported = ref(undefined)
  const isLoading = ref(false)
  const form = ref({})
  const formRef = ref(null)
  useEventJail(formRef)
  const isValid = useDebouncedWatchHandler([form, show], () => (!formRef.value || formRef.value.querySelectorAll('.is-invalid').length === 0))

  const reset = () => {
    const { 0: { value: mode } = {} } = modeOptions.value
    form.value = { mode }
  }

  const certOptions = computed(() => {
    const requireKey = form.value.mode === 'cert'
    // re-evaluate when the modal is shown to pick up new certificates
    return (show.value)
      ? $store.dispatch('$_pkis/allCerts').then(certs => certs
        .filter(cert => !requireKey || !cert.csr)
        .map(cert => ({ value: cert.id, text: `${cert.cn} (${cert.profile_name})` }))
      )
      : Promise.resolve([])
  })

  const onImport = () => {
    const { mode, cert_id, ca_id, ...csr } = form.value
    let promise
    switch (mode) {
      case 'cert': {
        const { cn } = ($store.state.$_pkis.certListCache || []).find(cert => cert.id === cert_id) || {}
        promise = apiCall.post('config/certificates/pki/import', { mode, cert_id })
          .then(({ data }) => ({ data, label: cn || cert_id }))
        break
      }
      case 'csr':
        promise = apiCall.post('config/certificates/pki/import', { mode, private_key: privateKey.value, ...csr })
          .then(({ data }) => ({ data, label: csr.common_name }))
        break
      case 'public':
        promise = $store.dispatch('$_pkis/getCert', cert_id)
          .then(cert => $store.dispatch('$_pkis/getCa', cert.ca_id)
            .then(ca => ({ data: { certificate: cert.cert, ca: ca.cert }, label: cert.cn }))
          )
        break
      case 'ca':
        promise = $store.dispatch('$_pkis/getCa', ca_id)
          .then(ca => ({ data: { ca: ca.cert }, label: ca.cn }))
        break
    }
    isLoading.value = true
    return promise
      .then(({ data, label }) => {
        const { warnings = [], ...pems } = data
        warnings.forEach(message => $store.dispatch('notification/warning', { message }))
        imported.value = i18n.t('Imported {name}, save to apply.', { name: label })
        emit('import', pems)
        show.value = false
      })
      .catch(() => {}) // errors are notified by the api interceptor
      .finally(() => {
        isLoading.value = false
      })
  }

  return {
    isServiceAlive,
    modeOptions,
    show,
    imported,
    isLoading,
    form,
    formRef,
    schema,
    isValid,
    reset,
    certOptions,
    onImport
  }
}

// @vue/component
export default {
  name: 'button-pki-import',
  components,
  props,
  setup
}
</script>
