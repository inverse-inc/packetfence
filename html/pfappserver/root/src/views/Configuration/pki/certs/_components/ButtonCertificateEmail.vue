<template>
  <b-button-group v-if="!isClone && !isNew && !isScep && !isCsr">
    <b-button :size="size" variant="outline-primary" :disabled="disabled || isLoading" @click="onShowModal">{{ $t('Email') }}</b-button>
    <b-modal v-model="isShowModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Email PKCS-12 Certificate') }}</h4>
        <b-form-text v-t="'Optionally specify a password to encrypt the certificate. Leave empty to generate one automatically — the generated password is included in the email body.'" class="mb-0" />
      </template>
      <b-form-group @submit.prevent="onEmail" class="mb-0">
        <base-form ref="rootRef"
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-password namespace="password"
            :column-label="$i18n.t('Password')"
            :text="$i18n.t('The certificate will be encrypted with this password. Leave empty to auto-generate.')"
          />
        </base-form>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" :disabled="isLoading" @click="onHideModal">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" :disabled="isLoading || !isValid" @click="onEmail">
          <icon v-if="isLoading" class="mr-1" name="circle-notch" spin /> {{ $t('Send Email') }}
        </b-button>
      </template>
    </b-modal>
  </b-button-group>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupInputPassword as FormGroupPassword
} from '@/components/new/'

const components = {
  BaseForm,
  FormGroupPassword
}

const props = {
  id : {
    type: [String, Number]
  },
  isClone: {
    type: Boolean
  },
  isNew: {
    type: Boolean
  },
  disabled: {
    type: Boolean
  },
  size: {
    type: String,
    default: "md",
    validator: value => ['sm', 'md', 'lg'].includes(value)
  }
}

import i18n from '@/utils/locale'
import yup from '@/utils/yup'

// Password is optional here (empty → server auto-generates). When supplied
// it must be at least 8 characters to match the Download form's policy.
const schema = yup.object({
  password: yup.string().notRequired().test(
    'min-when-set',
    i18n.t('Password must be at least 8 characters.'),
    value => !value || value.length >= 8
  )
})

import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import StoreModule from '../../_store'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const cert = ref({})
  watch(id, () => {
    if(!id.value) {
      cert.value = {}
    }
    else {
      $store.dispatch('$_pkis/getCert', id.value)
        .then(_cert => cert.value = _cert)
    }
  }, { immediate: true })
  const isScep = computed(() => {
    const { scep } = cert.value
    return scep
  })
  const isCsr = computed(() => {
    const { csr } = cert.value
    return csr
  })

  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const rootRef = ref(null)
  const form = ref({})

  const isShowModal = ref(false)
  const onShowModal = () => {
    form.value = {}
    isShowModal.value = true
  }
  const onHideModal = () => { isShowModal.value = false }
  const isValid = useDebouncedWatchHandler([form, isShowModal], () => (!rootRef.value || rootRef.value.$el.querySelectorAll('.is-invalid').length === 0))

  const onEmail = () => {
    const { cn, mail } = cert.value
    const { password } = form.value || {}
    $store.dispatch('$_pkis/emailCert', { id: id.value, password }).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Certificate <code>{cn}</code> emailed to <code>{mail}</code>.', { cn, mail }) })
      onHideModal()
    }).catch(e => {
      $store.dispatch('notification/danger', { message: i18n.t('Could not email certificate <code>{cn}</code> to <code>{mail}</code>: ', { cn, mail }) + e })
    })
  }

  return {
    isLoading,
    rootRef,
    form,
    schema: ref(schema),
    isScep,
    isCsr,
    isValid,
    isShowModal,
    onShowModal,
    onHideModal,
    onEmail
  }
}

// @vue/component
export default {
  name: 'button-certificate-email',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
