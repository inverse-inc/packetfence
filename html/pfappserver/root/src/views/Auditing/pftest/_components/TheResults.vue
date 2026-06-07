<template>
  <div class="px-3 pb-3">
    <h5 class="mt-3">{{ $t('Results') }}</h5>
    <b-card v-for="(r, idx) in results" :key="idx" class="mb-3" no-body>
      <b-card-header class="d-flex align-items-center py-2">
        <b-badge :variant="badgeVariant(r.exit_code)" pill class="mr-2">
          {{ $t('exit') }}: {{ r.exit_code }}
        </b-badge>
        <strong>{{ r.host }}</strong>
        <b-button variant="link" size="sm" class="ml-auto" @click="copyOne(r)">
          <icon name="clipboard" class="mr-1" />{{ $t('Copy') }}
        </b-button>
      </b-card-header>
      <b-card-body class="p-0">
        <pre class="text-monospace m-0 p-3 small" style="white-space: pre-wrap; word-break: break-word; max-height: 24rem; overflow-y: auto;">{{ r.output }}</pre>
      </b-card-body>
    </b-card>
  </div>
</template>

<script>
const props = { results: { type: Array, default: () => [] } }

const setup = (props, context) => {
  const { root: { $store } = {} } = context
  const badgeVariant = code => {
    if (code === 0) return 'success'
    if (code === -1) return 'warning'
    return 'danger'
  }
  const copyOne = r => {
    try {
      navigator.clipboard.writeText(r.output || '').then(() => {
        $store.dispatch('notification/info', { message: 'Copied output to clipboard.' })
      })
    } catch (e) { /* clipboard not available */ }
  }
  return { badgeVariant, copyOne }
}

export default { name: 'the-results', props, setup }
</script>
