<template>
  <b-modal v-model="show"
    size="xl" body-class="d-flex justify-content-md-center p-3"
  >
    <template v-slot:modal-title>
      {{ $i18n.t('View File') }} <code>{{ path }}</code>
    </template>
    <template v-slot:default>
      <img :src="previewUrl" class="align-self-center" />
    </template>
    <template v-slot:modal-footer>
      <button-delete v-if="isDeletable"
        variant="danger" class="mr-1"
        :disabled="isLoading"
        :confirm="$t('Delete file?')"
        reverse
        @click="onDelete"
      >{{ $t('Delete') }}</button-delete>
      <b-button
        class="mr-1" variant="secondary" @click="onHide">{{ $t('Close') }}</b-button>
    </template>
  </b-modal>
</template>
<script>
import {
  BaseButtonConfirm,
} from '@/components/new/'

const components = {
  ButtonDelete: BaseButtonConfirm,
}

const props = {
  entries: {
    type: Array
  },
  id: {
    type: String
  },
  path: {
    type: String,
    default: ''
  },
  value: { // v-model: show/hide
    type: Boolean
  }
}

import { computed, customRef, ref, toRefs, watch } from '@vue/composition-api'

const setup = (props, context) => {

  const { root: { $store } = {}, emit } = context

  const {
    entries,
    id,
    path,
    value,
  } = toRefs(props)

  const isLoading = computed(() => $store.getters['$_connection_profiles/isLoadingFiles'])

  const isDeletable = ref(false)
  const isRevertible = ref(false)
  watch([path, entries], () => {
    $store.dispatch('$_connection_profiles/getFile', { id: id.value, filename: path.value }).then(response => {
      const { meta: { not_deletable, not_revertible } = {} } = response
      isDeletable.value = !not_deletable
      isRevertible.value = !not_revertible
    })
  }, { deep: true })

  const previewUrl = computed(() => {
    let url = ['/config/profile', id.value, 'preview']
    if (path.value)
      url.push(...path.value.split('/').filter(u => u))
    return url.join('/')
  })

  const onDelete = () => {
    $store.dispatch('$_connection_profiles/deleteFile', { id: id.value, filename: path.value }).then(() => {
      emit('delete', path.value)
    })
  }

  const show = customRef((track, trigger) => ({ // use v-model
    get() {
      track()
      return value.value
    },
    set(newValue) {
      emit('input', newValue)
      trigger()
    }
  }))

  const onHide = () => {
    show.value = false
  }

  return {
    isLoading,
    isDeletable,
    isRevertible,
    onDelete,

    // modal
    show,
    onHide,

    previewUrl
  }
}

export default {
  name: 'modal-view',
  components,
  props,
  setup
}
</script>
