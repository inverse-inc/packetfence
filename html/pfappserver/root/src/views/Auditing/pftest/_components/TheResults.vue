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
        <pre class="pftest-output m-0 p-3 small">
          <template v-for="(line, lineIdx) in lines(r.output)">
            <span :key="lineIdx" :class="lineClass(line)">{{ line }}</span><br :key="`br-${lineIdx}`" />
          </template>
        </pre>
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

  // Mirror the CLI's pf::util::console::colors palette without depending on
  // ANSI escapes (Capture::Tiny disables is_interactive() so pftest never
  // emits the codes when run from the API). Match the same phrases pftest
  // prints with the success/warning/error helpers.
  const lines = output => (output || '').split('\n')
  const lineClass = line => {
    if (/\bAuthentication\s+SUCCEEDED\b/.test(line)) return 'pftest-success'
    if (/\bAuthentication\s+CHALLENGE\b/.test(line)) return 'pftest-warning'
    if (/\bAuthentication\s+FAILED\b/.test(line))    return 'pftest-error'
    if (/^Found\s+'[^']+'\s+profile\s+for\b/.test(line)) return 'pftest-success'
    if (/^Testing authentication for /.test(line))   return 'pftest-bold'
    if (/^Authenticating against /.test(line))       return 'pftest-info'
    if (/^\s+(Matched against|set_)/.test(line))     return 'pftest-muted'
    if (/^\s+Did not match/.test(line))              return 'pftest-muted'
    if (/^ERROR:/.test(line))                        return 'pftest-error'
    return ''
  }

  return { badgeVariant, headerBg, cardVariant, badgeIcon, badgeText, copyOne, lines, lineClass }
}

export default { name: 'the-results', props, setup }
</script>

<style lang="scss">
.pftest-output {
  font-family: SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  white-space: pre-wrap;
  word-break: break-word;
  max-height: 28rem;
  overflow-y: auto;
  background: #1f2128;
  color: #cdd6e0;
  border-radius: 0 0 .25rem .25rem;
}
.pftest-success { color: #4ade80; }
.pftest-warning { color: #fbbf24; }
.pftest-error   { color: #f87171; font-weight: 600; }
.pftest-info    { color: #93c5fd; }
.pftest-muted   { color: #94a3b8; }
.pftest-bold    { font-weight: 600; color: #e2e8f0; }
</style>
