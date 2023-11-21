<template>
  <b-button-group>
    <b-button :size="size" variant="outline-primary" :disabled="disabled || isLoading" @click.stop.prevent="onShowFormModal">{{ $t('Generate CSR') }}</b-button>


    <b-modal v-model="isShowFormModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Generate Certificate Signing Request') }}</h4>
      </template>
      <b-form-group @submit.prevent="onGenerateCsr" class="mb-0">
        <base-form ref="rootRef"
          :form="formCopy"
          :schema="schema"
          :isLoading="isLoading"
        >
          <the-form-fields v-bind="{ form: formCopy, isCsr: true }" />
        </base-form>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="link" class="mr-1" :disabled="isLoading" @click="onSkip">{{ $t('I have a certificate') }}</b-button>
        <b-button variant="secondary" class="mr-1" :disabled="isLoading" @click="onCancel">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isLoading || !isValid" @click="onGenerateCsr">
          <icon v-if="isLoading" class="mr-1" name="circle-notch" spin /> {{ $t('Generate CSR') }}
        </b-button>
      </template>
    </b-modal>


    <b-modal v-model="isShowCsrModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Certificate Signing Request') }}</h4>
      </template>
      <input-group-csr
        v-model="caCsr"
        :column-label="$i18n.t('Certificate Signing Request')"
        :text="$i18n.t('Use this CSR and click Next to provide the Certificate.')"
        :disabled="true"
        auto-fit
      />
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" :disabled="isLoading" @click="onCancel">{{ $t('Cancel') }}</b-button>
        <b-button variant="outline-primary" class="mr-1" :disabled="isLoading" @click="onClipboard">{{ $t('Copy to Clipboard') }}</b-button>
        <b-button variant="primary" class="mr-1" :disabled="isLoading" @click="onSkip">{{ $t('Next') }}</b-button>
      </template>
    </b-modal>


    <b-modal v-model="isShowCertModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Certificate') }}</h4>
      </template>
      <base-form ref="rootRef"
        :form="formCertificate"
        :schema="schemaCertificate"
        :isLoading="isLoading"
      >
        <input-group-cert namespace="cert"
          :column-label="$i18n.t('Certificate')"
          :text="$i18n.t('Provide the new certificate and click Save.')"
          auto-fit
        />
      </base-form>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" :disabled="isLoading" @click="onCancel">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" class="mr-1" :disabled="isLoading || !isCertificateValid" @click="onSave">{{ $t('Save') }}</b-button>
      </template>
    </b-modal>
  </b-button-group>
</template>
<script>
import { BaseForm } from '@/components/new/'
import { InputGroupCert, InputGroupCsr } from './'
import TheFormFields from './TheFormFields'

const components = {
  BaseForm,
  InputGroupCert,
  InputGroupCsr,
  TheFormFields,
}

const props = {
  id : {
    type: [String, Number]
  },
  disabled: {
    type: Boolean
  },
  form: {
    type: Object,
    default: () => ({})
  },
  size: {
    type: String,
    default: "md",
    validator: value => ['sm', 'md', 'lg'].includes(value)
  }
}

import i18n from '@/utils/locale'
import yup from '@/utils/yup'
import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import schemaFn from '../schema'
import { useStore } from '../_composables/useCollection'
import StoreModule from '../../_store'

const setup = (props, context) => {

  const schema = computed(() => schemaFn(props))

  const {
    id,
    form
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  const {
    generateCsrItem,
    updateItem
  } = useStore($store)

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const rootRef = ref(null)

  const formCopy = ref()
  watch(form, () => {
  const { cert, ...formWithoutCert } = JSON.parse(JSON.stringify(form.value)) // dereference form
    formCopy.value = formWithoutCert
  }, { deep: true, immediate: true })

  const onCancel = () => {
    onHideFormModal()
    onHideCsrModal()
    onHideCertModal()
  }

  const isShowFormModal = ref(false)
  const onShowFormModal = () => { isShowFormModal.value = true }
  const onHideFormModal = () => { isShowFormModal.value = false }
  const isValid = useDebouncedWatchHandler([formCopy, isShowFormModal], () => (!rootRef.value || rootRef.value.$el.querySelectorAll('.is-invalid').length === 0))
  const caCsr = ref(undefined)
  const onGenerateCsr = () => {
    generateCsrItem({ id: id.value, ...formCopy.value }).then(csr => {
      $store.dispatch('notification/info', { message: i18n.t('Certificate signing request <code>{id}</code> successful.', { id: id.value }) })
      onHideFormModal()
      onShowCsrModal()
      caCsr.value = csr
      formCertificate.value = { ...formCertificate.value, cert: undefined }
    }).catch(e => {
      $store.dispatch('notification/danger', { message: i18n.t('Certificate signing request <code>{id}</code> failed.<br/>Reason: ', { id: id.value }) + e })
      onShowFormModal()
    })
  }

  const isShowCsrModal = ref(false)
  const onShowCsrModal = () => { isShowCsrModal.value = true }
  const onHideCsrModal = () => { isShowCsrModal.value = false }

  const onSkip = () => {
    onHideFormModal()
    onHideCsrModal()
    onShowCertModal()
  }

  const onClipboard = () => {
    try {
      navigator.clipboard.writeText(caCsr.value).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('CSR copied to clipboard.') })
      }).catch(() => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not copy CSR to clipboard.') })
      })
    } catch (e) {
      $store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
    }
  }

  const isShowCertModal = ref(false)
  const onShowCertModal = () => { isShowCertModal.value = true }
  const onHideCertModal = () => { isShowCertModal.value = false }
  const formCertificate = ref({})
  const isCertificateValid = useDebouncedWatchHandler([formCertificate, isShowCertModal], () => (!rootRef.value || rootRef.value.$el.querySelectorAll('.is-invalid').length === 0))
  const schemaCertificate = yup.object().shape({
    cert: yup.string()
      .nullable()
      .required(i18n.t('Certificate required.'))
  })
  const onSave = () => {
    updateItem({ ...formCertificate.value, id: id.value }).then(item => {
      emit('change', item)
      onHideCertModal()
    })
  }

  return {
    isLoading,
    rootRef,
    formCopy,
    schema,
    isValid,
    isShowFormModal,
    onShowFormModal,
    onHideFormModal,
    onGenerateCsr,
    caCsr,
    isShowCsrModal,
    onShowCsrModal,
    onHideCsrModal,
    onCancel,
    onSkip,
    onClipboard,
    isShowCertModal,
    onShowCertModal,
    onHideCertModal,
    formCertificate,
    schemaCertificate,
    isCertificateValid,
    onSave,
  }
}

// @vue/component
export default {
  name: 'button-ca-generate-csr',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
