<template>
  <b-card no-body>
    <b-card-header class="d-flex align-items-center">
      <h5 class="mb-0" v-t="'Files'" />
      <b-button size="sm" variant="link" class="ml-auto" @click="$emit('close')"><icon name="times" /></b-button>
    </b-card-header>
    <b-list-group flush>
      <b-list-group-item v-if="isLoading" class="text-muted"><icon name="circle-notch" spin /></b-list-group-item>
      <b-list-group-item v-else-if="loadError" class="text-danger small">{{ $t('Could not load files.') }} {{ loadError }}</b-list-group-item>
      <b-list-group-item v-else-if="!files.length" class="text-muted small" v-t="'No files yet. Attach one, or ask the assistant to export something.'" />
      <b-list-group-item v-for="file in files" :key="file.id" class="py-2">
        <div class="d-flex align-items-center">
          <b-link class="text-truncate small" @click="onDownload(file)">{{ file.name }}</b-link>
          <b-badge variant="light" class="ml-1">{{ file.kind }}</b-badge>
          <b-button size="sm" variant="link" class="ml-auto p-0 text-muted" @click="onDelete(file)"
            v-b-tooltip.hover.left.d300 :title="$t('Delete file')"><icon name="trash-alt" /></b-button>
        </div>
        <small class="text-muted">{{ size(file.size_bytes) }} &middot; <timeago :datetime="file.created * 1000" :auto-update="60" :locale="$i18n.locale" /></small>
      </b-list-group-item>
    </b-list-group>
    <b-card-footer class="small text-muted" v-if="!loadError">
      {{ $t('{used} used', { used: size(usedBytes) }) }}
      <template v-if="quotas"> &middot; {{ $t('max {max} per file', { max: size(quotas.file_max) }) }}</template>
      &middot; {{ $t('uploads are not indexed for search') }}
    </b-card-footer>
  </b-card>
</template>

<script>
import { computed, ref, watch } from '@vue/composition-api'
import bytes from '@/utils/bytes'
import { useDownload } from '@/composables/useDownload'
import api from '../_api'

const setup = (props, context) => {
  const { root: { $store } = {} } = context

  const threadId = computed(() => $store.state.$_assistant.threadId)
  // reload when the conversation changes or a reply/upload adds files
  const fileCount = computed(() => $store.state.$_assistant.entries.length)

  const files = ref([])
  const quotas = ref(null)
  const usedBytes = ref(0)
  const isLoading = ref(false)
  const loadError = ref('')
  const load = () => {
    isLoading.value = true
    loadError.value = ''
    api.files(threadId.value ? { thread_id: threadId.value } : {}).then(response => {
      files.value = response.files || []
      quotas.value = response.quotas || quotas.value
      usedBytes.value = response.used_bytes || 0
    }).catch(err => {
      files.value = []
      const { response: { status, data: { error, message } = {} } = {} } = err || {}
      loadError.value = error || message || (status ? `HTTP ${status}` : '')
    }).finally(() => { isLoading.value = false })
  }
  watch([threadId, fileCount], load, { immediate: true })

  const onDownload = file => api.downloadFile(file.id).then(response => useDownload(file.name, response.data, file.mime))
  const onDelete = file => api.deleteFile(file.id).then(load)
  const size = n => bytes.toHuman(n || 0, 1, true) + 'B'

  return { files, quotas, usedBytes, isLoading, loadError, onDownload, onDelete, size }
}

// @vue/component
export default {
  name: 'the-files',
  setup
}
</script>
