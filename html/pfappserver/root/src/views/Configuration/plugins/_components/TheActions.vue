<template>
  <div v-if="actions.length">
    <b-button v-for="(action, index) in actions" :key="index"
      size="sm" variant="outline-primary" class="mr-1 mb-1"
      :disabled="isRunning"
      @click.stop.prevent="onAction(action)"
    >
      <icon v-if="isRunning === action" name="circle-notch" spin class="mr-1" />
      {{ action.label }}
    </b-button>
    <b-modal v-model="showModal" :title="modalTitle" size="lg" centered ok-only scrollable>
      <pre class="mb-0" style="white-space: pre-wrap;">{{ modalText }}</pre>
      <template #modal-footer>
        <b-button variant="outline-primary" @click="onCopy">{{ $t('Copy to clipboard') }}</b-button>
        <b-button variant="primary" @click="showModal = false">{{ $t('Close') }}</b-button>
      </template>
    </b-modal>
  </div>
</template>
<script>
import { computed, ref, toRefs } from '@vue/composition-api'
import { useCollectionApi } from '../_api'
import { useManifest } from '../_composables/useCollection'

const props = {
  plugin: {
    type: String
  },
  collection: {
    type: String
  },
  item: {
    type: Object,
    default: () => ({})
  }
}

const setup = (props, context) => {

  const {
    plugin,
    item
  } = toRefs(props)

  const { root: { $store } = {} } = context

  const manifest = useManifest(props)
  const actions = computed(() => manifest.value.actions || [])

  const isRunning = ref(false)
  const showModal = ref(false)
  const modalTitle = ref('')
  const modalText = ref('')

  const onAction = action => {
    isRunning.value = action
    useCollectionApi(plugin.value, manifest.value).action(action, item.value)
      .then(response => {
        const { display = 'toast', field } = action
        const value = (field && response) ? response[field] : response
        const text = (typeof value === 'string') ? value : JSON.stringify(value, null, 2)
        if (display === 'modal-text') {
          modalTitle.value = action.label
          modalText.value = text
          showModal.value = true
        }
        else
          $store.dispatch('notification/info', { message: (response && response.message) || text })
      })
      .finally(() => {
        isRunning.value = false
      })
  }

  const onCopy = () => {
    navigator.clipboard.writeText(modalText.value).then(() => {
      $store.dispatch('notification/info', { message: context.root.$i18n.t('Copied to clipboard.') })
    })
  }

  return {
    actions,
    isRunning,
    showModal,
    modalTitle,
    modalText,
    onAction,
    onCopy
  }
}

// @vue/component
export default {
  name: 'the-actions',
  inheritAttrs: false,
  props,
  setup
}
</script>
