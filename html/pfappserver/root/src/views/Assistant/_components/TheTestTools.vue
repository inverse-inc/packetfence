<template>
  <b-modal v-model="show" size="lg" hide-footer dialog-class="the-test-tools" @show="onShow">
    <template #modal-title>
      <span class="the-tt-title">{{ $t('Test tools') }}</span>
      <span v-if="meta" class="the-tt-pill ml-2" :class="meta.enabled ? 'is-online' : 'is-offline'">{{ meta.enabled ? $t('helper online') : $t('helper offline') }}</span>
    </template>
    <p class="the-tt-intro mb-3">
      {{ $t('Run 802.1X / RADIUS tests and packet captures against PacketFence and see the raw output.') }}<br>
      <b-link class="the-tt-link" @click="onHealth">{{ showHealth ? $t('hide environment check') : $t('check environment') }}</b-link>
    </p>
    <div v-if="showHealth" class="the-tt-box mb-3">
      <icon v-if="!health" name="circle-notch" spin />
      <div v-else-if="health.error" class="text-danger">{{ health.error }}</div>
      <template v-else>
        <div class="mb-1" :class="health.ok ? 'text-success' : 'text-danger'">{{ health.ok ? $t('environment ready') : $t('environment not ready, fix the failing items') }}</div>
        <div v-for="check in health.checks" :key="check.name" class="the-tt-check">
          <icon :name="check.ok ? 'check' : 'times'" :class="check.ok ? 'text-success' : 'text-danger'" scale=".8" />
          <span class="the-tt-check-name">{{ check.name }}</span>
          <span class="the-tt-check-detail">{{ check.detail }}</span>
        </div>
      </template>
    </div>
    <b-alert :show="!!loadError" variant="danger">{{ $t('Test tools are unavailable.') }} {{ loadError }}</b-alert>
    <div v-if="!meta && !loadError" class="text-center"><icon name="circle-notch" spin /></div>
    <template v-if="meta">
      <div class="the-tt-field">
        <label for="the-tt-tool">{{ $t('Tool') }}</label>
        <b-form-select id="the-tt-tool" class="the-tt-primary" :value="tool" :options="toolOptions" @change="select" />
      </div>
      <div class="the-tt-field">
        <label for="the-tt-variant">{{ $t('Variant') }}</label>
        <b-form-select id="the-tt-variant" :value="variant" :options="variantOptions" @change="select(tool, $event)" />
      </div>
      <div v-for="field in fields" :key="`${tool}-${variant}-${field.name}`" class="the-tt-field">
        <label :for="`the-tt-${field.name}`">{{ field.label }}</label>
        <b-form-select v-if="field.type === 'select'" :id="`the-tt-${field.name}`" v-model="params[field.name]" :options="selectOptions(field)" />
        <b-form-input v-else :id="`the-tt-${field.name}`" v-model="params[field.name]" :type="(field.type === 'password') ? 'password' : 'text'" autocomplete="off" />
      </div>
      <div v-if="config !== null" class="the-tt-field">
        <label for="the-tt-config">
          {{ $t('Editable config (runs exactly what is below)') }}
          <b-link class="the-tt-link ml-1" @click="onPreview">{{ $t('reset to defaults') }}</b-link>
        </label>
        <b-form-textarea id="the-tt-config" v-model="config" rows="8" class="text-monospace small" spellcheck="false" />
        <small class="text-muted">{{ $t('Edit freely, then run. Target host and secret are fixed by the server.') }}</small>
      </div>
      <div class="d-flex mt-4">
        <b-button variant="outline-secondary" class="the-tt-btn flex-fill mr-3" :disabled="!canWrite || isRunning" @click="onPreview">{{ $t('Preview') }}</b-button>
        <b-button variant="primary" class="the-tt-btn flex-fill" :disabled="!canWrite || isRunning" @click="onRun">
          <icon v-if="isRunning" name="circle-notch" spin class="mr-1" />
          {{ isCapture ? $t('Run capture') : $t('Run test') }}
        </b-button>
      </div>
      <small v-if="!canWrite" class="d-block text-danger mt-1" v-t="'Running tests needs the CHATBOT_WRITE admin role.'" />
      <div v-if="message" class="small mt-2" :class="{ 'text-danger': messageBad, 'text-muted text-monospace': !messageBad }">{{ message }}</div>
      <b-alert v-if="verdict !== null" show class="mt-2 mb-0" :variant="verdict ? 'success' : 'danger'">
        {{ verdict ? $t('Authentication succeeded.') : $t('Authentication did not succeed.') }}
        <b-button size="sm" variant="primary" class="ml-2" @click="onAnalyze">{{ $t('Analyze with logs') }}</b-button>
      </b-alert>
      <pre v-if="output" class="mt-2 mb-0 p-2 bg-light border small the-test-tools-output">{{ output }}</pre>
    </template>
  </b-modal>
</template>

<script>
import { computed, customRef, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'

const props = {
  value: {
    type: Boolean
  },
  // prefill from a chat request (pf_run_test / pf_capture): { tool, variant, fields }
  prepare: {
    type: Object
  }
}

const errorOf = err => {
  const { response: { status, data: { error, message } = {} } = {} } = err || {}
  if (error || message)
    return error || message
  if (status === 403)
    return i18n.t('Your admin role lacks CHATBOT_WRITE.')
  return i18n.t('Request failed.')
}

const setup = (props, context) => {
  const { emit, root: { $can, $store } = {} } = context

  const show = customRef((track, trigger) => ({ // use v-model
    get() {
      track()
      return props.value
    },
    set(newValue) {
      emit('input', newValue)
      trigger()
    }
  }))
  const canWrite = computed(() => $can('write', 'chatbot'))

  const meta = ref(null)
  const tool = ref(null)
  const variant = ref(null)
  const params = ref({})
  const interfaces = ref([])
  const config = ref(null)
  const message = ref('')
  const messageBad = ref(false)
  const output = ref('')
  const verdict = ref(null)
  const isRunning = ref(false)

  const toolOptions = computed(() => Object.entries((meta.value && meta.value.tools) || {}).map(([value, t]) => ({ value, text: t.label })))
  const toolMeta = computed(() => (meta.value && meta.value.tools[tool.value]) || { variants: {} })
  const variantOptions = computed(() => Object.entries(toolMeta.value.variants).map(([value, v]) => ({ value, text: v.label })))
  const fields = computed(() => (toolMeta.value.variants[variant.value] || {}).fields || [])
  const isCapture = computed(() => !!toolMeta.value.capture)

  // the interface list is discovered at runtime
  const selectOptions = field => {
    const options = (field.name === 'iface' && interfaces.value.length) ? [...interfaces.value, 'any'] : (field.options || [])
    const current = params.value[field.name]
    return (current && !options.includes(current)) ? [...options, current] : options
  }

  // pick a tool/variant and reset its fields to the defaults, overlaid with `keep`
  const select = (t, v, keep = {}) => {
    tool.value = t
    variant.value = (v && v in toolMeta.value.variants) ? v : (variantOptions.value[0] || {}).value
    params.value = fields.value.reduce((p, f) => ({ ...p, [f.name]: ([undefined, null, ''].includes(keep[f.name])) ? (f.default || '') : String(keep[f.name]) }), {})
    config.value = null
    message.value = ''
    output.value = ''
    verdict.value = null
  }
  watch(isCapture, capture => {
    if (capture && !interfaces.value.length && canWrite.value) {
      api.testToolsCapture({ preview: true, params: { preset: 'radius' } }).then(({ ok, preview }) => {
        if (ok && preview && preview.interfaces) {
          interfaces.value = preview.interfaces
          // start on the first real interface instead of an empty select
          if ('iface' in params.value && !params.value.iface && preview.interfaces.length)
            params.value = { ...params.value, iface: preview.interfaces[0] }
        }
      }).catch(() => {})
    }
  })

  const loadError = ref('')
  const onShow = () => {
    loadError.value = ''
    api.testTools().then(response => {
      meta.value = response
      const { tool: t, variant: v, fields: f } = props.prepare || {}
      if (t && t in response.tools)
        select(t, v, f)
      else if (!tool.value)
        select(Object.keys(response.tools)[0])
    }).catch(err => {
      meta.value = null
      loadError.value = errorOf(err)
    })
  }

  const showHealth = ref(false)
  const health = ref(null)
  const onHealth = () => {
    showHealth.value = !showHealth.value
    if (showHealth.value && !health.value)
      api.testToolsHealth().then(response => { health.value = response }).catch(err => { health.value = { error: errorOf(err) } })
  }

  const cleanParams = () => Object.entries(params.value).reduce((p, [k, v]) => (String(v).trim() ? { ...p, [k]: v } : p), {})
  const payload = (preview, useConfig) => {
    const p = cleanParams()
    if (useConfig && config.value && config.value.trim())
      p.config = config.value
    return { tool: tool.value, params: p, preview, ...((tool.value === 'eapol_test') ? { eap: variant.value } : {}) }
  }
  const setMessage = (text, bad = false) => {
    message.value = text
    messageBad.value = bad
  }

  const onPreview = () => {
    setMessage(i18n.t('building...'))
    output.value = ''
    verdict.value = null
    const request = isCapture.value
      ? api.testToolsCapture({ preview: true, params: cleanParams() })
      : api.testToolsRun(payload(true))
    request.then(({ ok, preview, error }) => {
      if (!ok || !preview)
        return setMessage(error || i18n.t('preview failed'), true)
      setMessage(`# ${preview.command}`)
      // config_editable is the real, runnable config; config is masked for display
      if (!isCapture.value)
        config.value = preview.config_editable || preview.config
    }).catch(err => setMessage(errorOf(err), true))
  }

  const lastRun = ref(null)
  const onRun = () => {
    isRunning.value = true
    output.value = ''
    verdict.value = null
    if (isCapture.value) {
      const p = cleanParams()
      setMessage(i18n.t('capturing... (up to {seconds}s)', { seconds: p.seconds || 20 }))
      return api.testToolsCapture({ params: p }).then(({ ok, summary, error }) => {
        if (!ok) {
          setMessage(error || i18n.t('capture failed'), true)
          return
        }
        show.value = false
        emit('send', `Analyze this packet capture summary (preset: ${p.preset}, filter: ${p.filter || '-'}):\n\n\`\`\`\n${summary || '(no summary)'}\n\`\`\``)
      }).catch(err => setMessage(errorOf(err), true)).finally(() => { isRunning.value = false })
    }
    setMessage(i18n.t('running test... (up to ~20s)'))
    return api.testToolsRun(payload(false, true)).then(({ ok, rc, output: out, error }) => {
      if (!ok) {
        setMessage(error || i18n.t('run failed'), true)
        output.value = error || ''
        return
      }
      const text = out || '(no output)'
      const pass = /SUCCESS|Access-Accept|EAP-SUCCESS/.test(text) && !/FAILURE|Access-Reject/.test(text)
      setMessage(i18n.t('completed (exit {rc})', { rc }))
      output.value = text
      verdict.value = pass
      lastRun.value = { text, pass, params: cleanParams(), tool: tool.value, variant: variant.value }
      $store.dispatch('$_assistant/addNote', {
        label: i18n.t('test tools'),
        content: `**Test tool: ${tool.value} / ${variant.value}** — ${pass ? '✓ success' : '✗ failed'}\n\`\`\`\n${text.split('\n').slice(-12).join('\n')}\n\`\`\``
      })
    }).catch(err => setMessage(errorOf(err), true)).finally(() => { isRunning.value = false })
  }

  // hand the result to the assistant: fetch the logs for the tested identity
  const onAnalyze = () => {
    const { text, params: p, tool: t, variant: v } = lastRun.value
    const ident = p.identity || p.username || p.user || p.mac || ''
    const label = t + ((t === 'eapol_test') ? ` (${v})` : '')
    show.value = false
    emit('send', `Analyze this ${label} authentication test result${ident ? ` for ${ident}` : ''}. `
      + `Fetch the relevant PacketFence logs${ident ? ` for ${ident}` : ''} and give the full diagnose-style report `
      + `(Recent log entries, Verdict, Details, Overall analysis). Test output:\n\n\`\`\`\n${text}\n\`\`\``)
  }

  return {
    show,
    canWrite,
    meta,
    loadError,
    tool,
    variant,
    params,
    config,
    message,
    messageBad,
    output,
    verdict,
    isRunning,
    toolOptions,
    variantOptions,
    fields,
    isCapture,
    selectOptions,
    select,
    onShow,
    showHealth,
    health,
    onHealth,
    onPreview,
    onRun,
    onAnalyze
  }
}

// @vue/component
export default {
  name: 'the-test-tools',
  props,
  setup
}
</script>

<style lang="scss">
.the-test-tools-output {
  max-height: 20rem;
  overflow-y: auto;
  white-space: pre-wrap;
}
.the-test-tools {
  $mono: $font-family-monospace;
  .the-tt-title {
    font-weight: 700;
    letter-spacing: .04em;
    text-transform: uppercase;
  }
  .the-tt-pill {
    display: inline-block;
    padding: .1rem .6rem;
    font-family: $mono;
    font-size: .72rem;
    letter-spacing: .08em;
    text-transform: uppercase;
    vertical-align: middle;
    border: 1px solid currentColor;
    border-radius: 1rem;
    &.is-online  { color: $success; background-color: lighten($success, 52%); }
    &.is-offline { color: $danger;  background-color: lighten($danger, 42%); }
  }
  .the-tt-intro {
    font-family: $mono;
    font-size: .82rem;
    color: $gray-600;
  }
  .the-tt-link {
    font-family: $mono;
    text-decoration: underline;
  }
  .the-tt-box {
    padding: .75rem 1rem;
    font-family: $mono;
    font-size: .82rem;
    background-color: $gray-100;
    border: 1px solid $gray-300;
    border-radius: .65rem;
  }
  .the-tt-check {
    display: grid;
    grid-template-columns: 1.5rem 11rem 1fr;
    align-items: baseline;
    padding: .1rem 0;
    .the-tt-check-name { color: $gray-900; }
    .the-tt-check-detail { color: $gray-600; }
  }
  .the-tt-field {
    margin-bottom: 1rem;
    > label {
      display: block;
      margin-bottom: .35rem;
      font-family: $mono;
      font-size: .74rem;
      letter-spacing: .08em;
      text-transform: uppercase;
      color: $gray-700;
    }
    .form-control, .custom-select {
      height: calc(1.5em + 1.25rem + 2px);
      border-radius: .6rem;
    }
    textarea.form-control { height: auto; }
    .the-tt-primary { border-color: $primary; }
  }
  .the-tt-btn {
    min-height: 2.75rem;
    font-weight: 600;
    border-radius: .6rem;
  }
}
</style>
