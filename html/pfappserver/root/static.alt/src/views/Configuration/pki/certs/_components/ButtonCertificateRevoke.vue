<template>
  <b-button-group v-if="!isClone && !isNew">
    <b-button size="sm" variant="outline-danger" :disabled="isLoading" @click="onShowModal">{{ $t('Revoke') }}</b-button>
    <b-modal v-model="isShowModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Revoke Certificate') }}</h4>
        <b-form-text v-t="'Choose a reason to revoke the certificate.'" class="mb-0" />
      </template>
      <b-form-group @submit.prevent="onRevoke" class="mb-0">
        <base-form ref="rootRef"
          :form="form"
          :schema="schema"
          :isLoading="isLoading"
        >
          <form-group-reason namespace="reason"
            :column-label="$i18n.t('Reason')"
            :options="reasonsOptions"
          />
        </base-form>
      </b-form-group>
      <template v-slot:modal-footer>
        <b-button variant="secondary" class="mr-1" :disabled="isLoading" @click="onHideModal">{{ $t('Cancel') }}</b-button>
        <b-button variant="danger" :disabled="isLoading || !isValid" @click="onRevoke">
          <icon v-if="isLoading" class="mr-1" name="circle-notch" spin /> {{ $t('Revoke') }}
        </b-button>
      </template>
    </b-modal>
  </b-button-group>
</template>
<script>
import {
  BaseForm,
  BaseFormGroupChosenOne as FormGroupReason
} from '@/components/new/'

const components = {
  BaseForm,
  FormGroupReason
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
  reason: yup.string().required(i18n.t('Reason required.'))
})

import { computed, ref, toRefs } from '@vue/composition-api'
import { useDebouncedWatchHandler } from '@/composables/useDebounce'
import StoreModule from '../../_store'
import { revokeReasons } from '../../config'

const setup = (props, context) => {

  const {
    id
  } = toRefs(props)

  const { root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const rootRef = ref(null)
  const form = ref({})
  const isValid = useDebouncedWatchHandler(form, () => (!rootRef.value || rootRef.value.$el.querySelectorAll('.is-invalid').length === 0))

  const isShowModal = ref(false)
  const onShowModal = () => { isShowModal.value = true }
  const onHideModal = () => { isShowModal.value = false }
  const onRevoke = () => {
    const { reason } = form.value || {}
    $store.dispatch('$_pkis/getCert', id.value).then(cert => {
      const { cn } = cert
      $store.dispatch('$_pkis/revokeCert', { id: id.value, reason }).then(() => {
        $store.dispatch('notification/info', { message: i18n.t('Certificate <code>{cn}</code> revoked.', { cn }) })
      }).catch(e => {
        $store.dispatch('notification/danger', { message: i18n.t('Could not revoke certificate <code>{cn}</code>.<br/>Reason: ', { cn }) + e })
      }).finally(() => {
        onHideModal()
      })
    })
  }

  return {
    isLoading,
    rootRef,
    form,
    schema: ref(schema),
    isValid,
    isShowModal,
    onShowModal,
    onHideModal,
    onRevoke,
    reasonsOptions: revokeReasons
  }
}

// @vue/component
export default {
  name: 'button-certificate-revoke',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
