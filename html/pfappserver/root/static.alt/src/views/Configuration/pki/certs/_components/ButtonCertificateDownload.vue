<template>
  <b-button-group v-if="!isClone && !isNew">
    <b-button size="sm" variant="outline-primary" :disabled="isLoading" @click="onShowModal">{{ $t('Download') }}</b-button>
    <b-modal v-model="isShowModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Download PKCS-12 Certificate') }}</h4>
        <b-form-text v-t="'Choose a password to encrypt the certificate.'" class="mb-0" />
      </template>
      <b-form-group @submit.prevent="onDownload" class="mb-0">
        <base-form ref="rootRef"
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-password namespace="password"
            :column-label="$i18n.t('Password')"
            :text="$i18n.t('The certificate will be encrypted with this password.')"
          />
          <form-group-clipboard v-model="clipboard"
            :column-label="$i18n.t('Copy to clipboard')"
            :text="$i18n.t('Copy the password to the clipboard')"
          />
        </base-form>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" :disabled="isLoading" @click="onHideModal">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isLoading || !isValid" @click="onDownload">
          <icon v-if="isLoading" class="mr-1" name="circle-notch" spin /> {{ $t('Download P12') }}
        </b-button>
      </template>
    </b-modal>
  </b-button-group>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupInputPassword as FormGroupPassword,
  BaseFormGroupToggleFalseTrue as FormGroupClipboard
} from '@/components/new/'

const components = {
  BaseForm,
  FormGroupPassword,
  FormGroupClipboard
}

const props = {
  id : {
    type: String
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  }
}

import i18n from '@/utils/locale'
import yup from '@/utils/yup'

const schema = yup.object({
  password: yup.string().required(i18n.t('Password required.')).min(8)
})

import { computed, ref, toRefs } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import StoreModule from '../../_store'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const rootRef = ref(null)
  const clipboard = ref(false)
  const form = ref({})

  const isShowModal = ref(false)
  const onShowModal = () => { isShowModal.value = true }
  const onHideModal = () => { isShowModal.value = false }
  const isValid = useDebouncedWatchHandler([form, isShowModal], () => (!rootRef.value || rootRef.value.$el.querySelectorAll('.is-invalid').length === 0))
  const onDownload = () => {
    $store.dispatch('$_pkis/getCert', id.value).then(cert => {
      const { ca_id, profile_id } = cert
      $store.dispatch('$_pkis/getProfile', profile_id).then(profile => {
        $store.dispatch('$_pkis/getCa', ca_id).then(ca => {
          const filename = `${ca.cn}-${profile.name}-${cert.cn}.p12`
          const { password } = form.value || {}
          $store.dispatch('$_pkis/downloadCert', { id: id.value, password }).then(arrayBuffer => {
            if (clipboard.value) {
              navigator.clipboard.writeText(password).then(() => {
                $store.dispatch('notification/info', { message: i18n.t('Certificate password copied to clipboard') })
              })
            }
            const blob = new Blob([arrayBuffer], { type: 'application/x-pkcs12' })
            if (window.navigator.msSaveOrOpenBlob) {
              window.navigator.msSaveBlob(blob, filename)
            } else {
              let elem = window.document.createElement('a')
              elem.href = window.URL.createObjectURL(blob)
              elem.download = filename
              document.body.appendChild(elem)
              elem.click()
              document.body.removeChild(elem)
            }
            onHideModal()
          })
        })
      })
    })
  }

  return {
    isLoading,
    rootRef,
    clipboard,
    form,
    schema: ref(schema),
    isValid,
    isShowModal,
    onShowModal,
    onHideModal,
    onDownload
  }
}

// @vue/component
export default {
  name: 'button-certificate-download',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
