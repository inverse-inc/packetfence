<template>
  <div class="px-3 pb-3">
    <h5 class="mt-3 mb-2">{{ $t('Results') }}</h5>
    <b-card v-for="(r, idx) in results" :key="idx" class="mb-3" no-body>
      <b-card-header class="d-flex align-items-center py-2 bg-light">
        <icon name="server" class="mr-2 text-muted" />
        <strong>{{ r.host }}</strong>
        <!-- Only surface the exit code when something actually went wrong on
             the controller side (negative). Authentication's CLI returns
             whatever `print` evaluates to (=1), which is meaningless as a
             test outcome — the per-source SUCCEEDED/FAILED lines in the
             output below already convey the real result. -->
        <small v-if="r.exit_code < 0" class="text-danger ml-2">
          <icon name="exclamation-triangle" class="mr-1" />{{ $t('controller error (exit {n})', { n: r.exit_code }) }}
        </small>
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
  const copyOne = r => {
    try {
      navigator.clipboard.writeText(r.output || '').then(() => {
        $store.dispatch('notification/info', { message: 'Copied output to clipboard.' })
      })
    } catch (e) { /* clipboard not available */ }
  }

  // Reproduce pf::util::console::colors client-side — Capture::Tiny strips ANSI server-side.
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

  return { copyOne, lines, lineClass }
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
