<template>
  <b-button-group>
    <b-button size="sm" variant="outline-danger" :disabled="disabled || isLoading" @click.stop.prevent="onShowModal">{{ $t('Resign CA Certificate') }}</b-button>
    <b-modal v-model="isShowModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Resign CA Certificate') }}</h4>
        <div class="small alert alert-danger mb-0">
          <strong>{{ $i18n.t('Warning') }}</strong>
          {{ $i18n.t('Changing the "Organisational Unit", "Organisation", "Country", "State or Province", "Locality", or "Street Address" will invalidate the previously signed certificates using EAP-TLS') }}.
        </div>
      </template>
      <b-form-group @submit.prevent="onResign" class="mb-0">
        <base-form ref="rootRef"
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-cn namespace="cn"
            :column-label="$i18n.t('Common Name')"
          />
          <form-group-mail namespace="mail"
            :column-label="$i18n.t('Email')"
          />
          <form-group-organisational-unit namespace="organisational_unit"
            :column-label="$i18n.t('Organisational Unit')"
          />
          <form-group-organisation namespace="organisation"
            :column-label="$i18n.t('Organisation')"
          />
          <form-group-country namespace="country"
            :column-label="$i18n.t('Country')"
          />
          <form-group-state namespace="state"
            :column-label="$i18n.t('State or Province')"
          />
          <form-group-locality namespace="locality"
            :column-label="$i18n.t('Locality')"
          />
          <form-group-street-address namespace="street_address"
            :column-label="$i18n.t('Street Address')"
          />
          <form-group-key-type namespace="key_type"
            :column-label="$i18n.t('Key type')"
            :disabled="true"
          />
          <form-group-key-size namespace="key_size"
            :column-label="$i18n.t('Key size')"
            :options="keySizeOptions"
            :disabled="true"
          />
          <form-group-digest namespace="digest"
            :column-label="$i18n.t('Digest')"
          />
          <form-group-key-usage namespace="key_usage"
            :column-label="$i18n.t('Key usage')"
            :text="$i18n.t('Optional. One or many of: digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign, encipherOnly, decipherOnly.')"
          />
          <form-group-extended-key-usage namespace="extended_key_usage"
            :column-label="$i18n.t('Extended key usage')"
            :text="$i18n.t('Optional. One or many of: serverAuth, clientAuth, codeSigning, emailProtection, timeStamping, msCodeInd, msCodeCom, msCTLSign, msSGC, msEFS, nsSGC.')"
          />
          <form-group-days namespace="days"
            :column-label="$i18n.t('Days')"
            :text="$i18n.t('Number of days the CA will be valid. (value greater than 825 wont work on some devices)')"
          />
          <form-group-ocsp-url namespace="ocsp_url"
            :column-label="$i18n.t('OCSP Url')"
            :text="$i18n.t('Optional. This is the url of the OCSP server that will be added in the certificate.')"
          />
        </base-form>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" :disabled="isLoading" @click="onHideModal">{{ $t('Cancel') }}</b-button>
        <b-button variant="danger" :disabled="isLoading || !isValid" @click="onResign">
          <icon v-if="isLoading" class="mr-1" name="circle-notch" spin /> {{ $t('Resign') }}
        </b-button>
      </template>
    </b-modal>
  </b-button-group>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupChosenCountry,
  BaseFormGroupInput,
  BaseFormGroupInputNumber,
} from '@/components/new/'
import {
  BaseFormGroupKeyType,
  BaseFormGroupKeySize,
  BaseFormGroupDigest,
  BaseFormGroupKeyUsage,
  BaseFormGroupExtendedKeyUsage,
} from '../../_components/'

const components = {
  BaseForm,
  FormGroupCn: BaseFormGroupInput,
  FormGroupMail: BaseFormGroupInput,
  FormGroupOrganisationalUnit: BaseFormGroupInput,
  FormGroupOrganisation: BaseFormGroupInput,
  FormGroupCountry: BaseFormGroupChosenCountry,
  FormGroupState: BaseFormGroupInput,
  FormGroupLocality: BaseFormGroupInput,
  FormGroupStreetAddress: BaseFormGroupInput,
  FormGroupPostalCode: BaseFormGroupInput,
  FormGroupOcspUrl: BaseFormGroupInput,
  FormGroupKeyType: BaseFormGroupKeyType,
  FormGroupKeySize: BaseFormGroupKeySize,
  FormGroupDigest: BaseFormGroupDigest ,
  FormGroupKeyUsage: BaseFormGroupKeyUsage,
  FormGroupExtendedKeyUsage: BaseFormGroupExtendedKeyUsage,
  FormGroupDays: BaseFormGroupInputNumber,
}

const props = {
  id : {
    type: [String, Number]
  },
  disabled: {
    type: Boolean
  },
  form: {
    type: Object
  }
}

import i18n from '@/utils/locale'

import { computed, ref, toRefs } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import schemaFn from '../schema'
import StoreModule from '../../_store'
import { keyTypes, keySizes } from '../../config'

const setup = (props, context) => {

  const schema = computed(() => schemaFn(props))

  const {
    id,
    form
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const rootRef = ref(null)

  const isShowModal = ref(false)
  const onShowModal = () => { isShowModal.value = true }
  const onHideModal = () => { isShowModal.value = false }
  const isValid = useDebouncedWatchHandler([form, isShowModal], () => (!rootRef.value || rootRef.value.$el.querySelectorAll('.is-invalid').length === 0))
  const onResign = () => {
    $store.dispatch('$_pkis/resignCa', { id: id.value, ...form.value }).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Certificate <code>{id}</code> resigned.', { id: id.value }) })
      emit('change')
      onHideModal()
    }).catch(e => {
      $store.dispatch('notification/danger', { message: i18n.t('Could not resign certificate <code>{id}</code>.<br/>Reason: ', { id: id.value }) + e })
    })
  }

  const keySizeOptions = computed(() => {
    const { key_type } = form.value || {}
    if (key_type) {
      const { [+key_type]: { sizes = [] } = {} } = keyTypes
      return sizes.map(size => ({ text: `${size}`, value: `${size}` }))
    }
    return keySizes
  })

  return {
    isLoading,
    rootRef,
    schema,
    isValid,
    isShowModal,
    onShowModal,
    onHideModal,
    onResign,
    keySizeOptions
  }
}

// @vue/component
export default {
  name: 'button-certificate-resign',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
