<template>
  <div class="px-3 pb-3">
    <div class="d-flex align-items-center mt-3 mb-2">
      <h5 class="mb-0">{{ $t('Results') }}</h5>
      <small class="ml-2 text-muted">
        {{ $t('exit 0 = pass; non-zero = the test produced a negative result (still shown).') }}
      </small>
    </div>
    <b-card v-for="(r, idx) in results" :key="idx" class="mb-3" no-body
      :border-variant="cardVariant(r.exit_code)">
      <b-card-header class="d-flex align-items-center py-2" :header-bg-variant="headerBg(r.exit_code)">
        <b-badge :variant="badgeVariant(r.exit_code)" pill class="mr-2">
          <icon :name="badgeIcon(r.exit_code)" class="mr-1" /> {{ badgeText(r.exit_code) }}
        </b-badge>
        <strong>{{ r.host }}</strong>
        <small class="text-muted ml-2">exit {{ r.exit_code }}</small>
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
  // Visual hierarchy:
  //  exit 0    -> success (green): the test passed
  //  exit > 0  -> warning (amber): the test produced a negative result —
  //              this is NOT an API error, the output is informative
  //  exit < 0  -> danger (red):    the controller could not run the test
  const badgeVariant = code => {
    if (code === 0)  return 'success'
    if (code < 0)    return 'danger'
    return 'warning'
  }
  const headerBg = code => {
    if (code === 0) return 'light'
    if (code < 0)   return 'light'
    return 'light'
  }
  const cardVariant = code => {
    if (code === 0) return 'success'
    if (code < 0)   return 'danger'
    return 'warning'
  }
  const badgeIcon = code => {
    if (code === 0) return 'check'
    if (code < 0)   return 'exclamation-triangle'
    return 'info-circle'
  }
  const badgeText = code => {
    if (code === 0) return 'PASS'
    if (code < 0)   return 'ERROR'
    return 'RESULT'
  }
  const copyOne = r => {
    try {
      navigator.clipboard.writeText(r.output || '').then(() => {
        $store.dispatch('notification/info', { message: 'Copied output to clipboard.' })
      })
    } catch (e) { /* clipboard not available */ }
  }
  return { badgeVariant, headerBg, cardVariant, badgeIcon, badgeText, copyOne }
}

export default { name: 'the-results', props, setup }
</script>
