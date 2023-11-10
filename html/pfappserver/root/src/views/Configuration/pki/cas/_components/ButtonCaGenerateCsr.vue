<template>
  <b-button-group>
    <b-button size="sm" variant="outline-primary" :disabled="disabled || isLoading" @click.stop.prevent="onGenerateCsr">{{ $t('Generate CSR') }}</b-button>
    <b-modal v-model="isShowOutputModal"
      size="lg" centered cancel-disabled>
      <template v-slot:modal-title>
        <h4>{{ $t('Certificate Signing Request') }}</h4>

      </template>
    </b-modal>
  </b-button-group>
</template>
<script>

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
import StoreModule from '../../_store'

const setup = (props, context) => {

  const {
    id,
    form
  } = toRefs(props)

  const { emit, root: { $store } = {} } = context

  if (!$store.state.$_pkis)
    $store.registerModule('$_pkis', StoreModule)

  const isLoading = computed(() => $store.getters['$_pkis/isLoading'])
  const rootRef = ref(null)
  const isShowOutputModal = ref(false)
  const onShowOutputModal = () => { isShowOutputModal.value = true }
  const onHideOutputModal = () => { isShowOutputModal.value = false }

  const onGenerateCsr = () => {
    onShowOutputModal()
    $store.dispatch('$_pkis/generateCsrCa', { id: id.value, ...form.value }).then(() => {
      $store.dispatch('notification/info', { message: i18n.t('Certificate <code>{id}</code> resigned.', { id: id.value }) })
      emit('change')
      onShowOutputModal()
    }).catch(e => {
      $store.dispatch('notification/danger', { message: i18n.t('Could not resign certificate <code>{id}</code>.<br/>Reason: ', { id: id.value }) + e })
      onShowOutputModal()
    })
  }

  return {
    isLoading,
    rootRef,
    isShowOutputModal,
    onShowOutputModal,
    onHideOutputModal,
    onGenerateCsr,
  }
}

// @vue/component
export default {
  name: 'button-ca-generate-csr',
  inheritAttrs: false,
  props,
  setup
}
</script>
