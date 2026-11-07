<template>
  <b-card no-body v-if="node">
    <b-card-header class="d-flex align-items-center">
      <h5 class="mb-0" v-t="'Node inspector'" />
      <b-button size="sm" variant="link" class="ml-auto" :disabled="isRefreshing" @click="onRefresh"
        v-b-tooltip.hover.bottom.d300 :title="$t('Re-read this node from the API')">
        <icon name="sync" :spin="isRefreshing" />
      </b-button>
      <b-button size="sm" variant="link" @click="$emit('close')"><icon name="times" /></b-button>
    </b-card-header>
    <b-card-body>
      <div class="text-monospace">
        <b-link :to="`/node/${node.mac}`">{{ node.mac }}</b-link>
      </div>
      <b-badge v-if="node.status" :variant="(status === 'registered') ? 'success' : (status === 'unregistered') ? 'warning' : 'light'">{{ node.status }}</b-badge>
      <dl class="row small mt-3 mb-0">
        <template v-for="fact in facts">
          <dt class="col-5 text-muted" :key="`dt-${fact.label}`">{{ fact.label }}</dt>
          <dd class="col-7 text-break" :key="`dd-${fact.label}`">{{ fact.value }}</dd>
        </template>
      </dl>
      <div class="mt-2">
        <b-button v-if="status !== 'registered'" block size="sm" variant="outline-primary" :disabled="!canWrite" @click="onStage('register')">{{ $t('Register node') }}</b-button>
        <b-button v-if="status !== 'unregistered'" block size="sm" variant="outline-danger" :disabled="!canWrite" @click="onStage('deregister')">{{ $t('Deregister node') }}</b-button>
        <b-button block size="sm" variant="outline-primary" :disabled="!canWrite" @click="onStage('reevaluate')">{{ $t('Reevaluate access') }}</b-button>
        <b-button block size="sm" variant="outline-secondary" :disabled="isSending" @click="$emit('send', `Diagnose ${node.mac}`)">{{ $t('Diagnose again') }}</b-button>
      </div>
      <b-form-group class="mt-3 mb-0" :label="$t('Change role')" label-size="sm">
        <b-input-group size="sm">
          <b-form-select v-model="role" :options="roleOptions" :disabled="!canWrite || !roleOptions.length" />
          <b-input-group-append>
            <b-button variant="primary" :disabled="!canWrite || !role || role === initialRole" @click="onStage('role', role)">{{ $t('Apply') }}</b-button>
          </b-input-group-append>
        </b-input-group>
      </b-form-group>
      <small class="text-muted d-block mt-3" v-t="'Changes are confirmed in the conversation before they run.'" />
    </b-card-body>
  </b-card>
</template>

<script>
import { computed, ref, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'

// fallback when the backend sends no ordered `facts` array
const FIELDS = [['status', 'Status'], ['role', 'Role'], ['vlan', 'VLAN'], ['pid', 'Owner'],
  ['device_type', 'Device'], ['last_seen', 'Last seen'], ['switch_ip', 'Switch'],
  ['connection_type', 'Connection'], ['profile', 'Profile'], ['notes', 'Notes']]

const setup = (props, context) => {
  const { root: { $can, $store } = {} } = context

  const node = computed(() => $store.state.$_assistant.nodeActions)
  const status = computed(() => ((node.value && node.value.status) || '').toLowerCase())
  const isSending = computed(() => $store.getters['$_assistant/isSending'])
  const canWrite = computed(() => $can('write', 'chatbot'))

  const facts = computed(() => {
    const { facts } = node.value || {}
    if (Array.isArray(facts))
      return facts.filter(f => f && f.label && f.value !== null && f.value !== undefined && String(f.value) !== '')
    return FIELDS
      .filter(([key]) => ![undefined, null, ''].includes(node.value[key]))
      .map(([key, label]) => ({ label: i18n.t(label), value: String(node.value[key]) }))
  })

  const roles = ref([])
  $store.dispatch('$_assistant/getRoles').then(items => { roles.value = items })
  const roleOptions = computed(() => roles.value.map(r => ({ value: r.category_id, text: r.name })))
  const initialRole = computed(() => {
    const current = ((node.value && node.value.role) || '').toLowerCase()
    const found = roles.value.find(r => r.name.toLowerCase() === current)
    return found ? found.category_id : null
  })
  const role = ref(null)
  watch(initialRole, value => { role.value = value }, { immediate: true })

  const onStage = (action, value) => $store.dispatch('$_assistant/stageNode', { mac: node.value.mac, action, value }).catch(() => {})

  const isRefreshing = ref(false)
  const onRefresh = () => {
    isRefreshing.value = true
    $store.dispatch('$_assistant/refreshNode', node.value.mac).finally(() => { isRefreshing.value = false })
  }

  return { node, status, isSending, canWrite, facts, roleOptions, initialRole, role, onStage, isRefreshing, onRefresh }
}

// @vue/component
export default {
  name: 'the-node-inspector',
  setup
}
</script>
