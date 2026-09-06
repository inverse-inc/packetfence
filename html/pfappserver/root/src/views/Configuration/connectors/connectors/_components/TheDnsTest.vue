<template>
  <div class="card mx-3 mb-3 bg-light">
    <div class="card-body">
      <b-row align-v="center" class="mb-2">
        <b-col>
          <h6 class="mb-0">{{ $i18n.t('Test DNS Resolution') }}</h6>
          <small class="text-muted">{{ $i18n.t('The query is sent through the connector tunnel to the selected DNS server, or resolved as PacketFence does. Any answer, including NXDOMAIN, proves the tunnel and the DNS server are reachable. Save the connector first: the test uses the saved servers.') }}</small>
        </b-col>
      </b-row>

      <b-form inline @submit.prevent="lookup">
        <b-form-select v-model="serverId" :options="serverOptions" class="mr-2" :disabled="mode === 'packetfence'" />
        <b-form-input v-model="name" class="mr-2 flex-grow-1"
          :placeholder="$i18n.t('Hostname to resolve, e.g. dc1.') + (firstDomain || 'example.com')"
        />
        <b-form-select v-model="type" :options="recordTypes" class="mr-2" />
        <b-form-select v-model="mode" :options="modes" class="mr-2" />
        <b-button type="submit" variant="primary" :disabled="isLoading || !name || (mode === 'tunnel' && !serverId)">
          <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />{{ $i18n.t('Lookup') }}
        </b-button>
        <b-button variant="outline-primary" class="ml-2" :disabled="isLoading || !firstDomain || (mode === 'tunnel' && !serverId)" @click="testServer">
          <icon name="stethoscope" class="mr-1" />{{ $i18n.t('Test Server') }}
        </b-button>
      </b-form>

      <div v-if="result" class="mt-3">
        <b-alert show :variant="alertVariant" class="mb-2">
          <b-row align-v="center">
            <b-col>
              <strong>{{ resultHeadline }}</strong>
              <div class="small">
                {{ $i18n.t('Query') }}: <span class="text-monospace">{{ result.name }} {{ result.type }}</span>
                <template v-if="result.mode === 'packetfence'">
                  — {{ $i18n.t('via pfdns-connector front-end (as PacketFence resolves)') }}
                  <span class="text-monospace">{{ result.dns_server }}</span>
                </template>
                <template v-else>
                  — {{ $i18n.t('via connector') }} <span class="text-monospace">{{ result.connector_id }}</span>,
                  {{ $i18n.t('tunnel port') }} <span class="text-monospace">{{ result.pfconnector_port }}</span>
                  → <span class="text-monospace">{{ result.dns_server }}</span>
                </template>
              </div>
            </b-col>
            <b-col cols="auto" v-if="result.reachable">
              <b-badge variant="light" class="border">{{ result.latency_ms }} ms</b-badge>
            </b-col>
          </b-row>
        </b-alert>
        <div v-if="result.answers && result.answers.length">
          <pre class="bg-dark text-light p-2 rounded mb-0"><code>{{ result.answers.join('\n') }}</code></pre>
        </div>
      </div>
    </div>
  </div>
</template>
<script>
import { computed, ref, toRefs, watch } from '@vue/composition-api'
import i18n from '@/utils/locale'
import api from '../_api'

export const props = {
  id: {
    type: String
  },
  form: {
    type: Object
  }
}

export const setup = (props) => {
  const { form } = toRefs(props)

  const name = ref('')
  const type = ref('A')
  const mode = ref('tunnel')
  const serverId = ref(null)
  const result = ref(null)
  const isLoading = ref(false)

  const recordTypes = ['A', 'AAAA', 'CNAME', 'MX', 'NS', 'PTR', 'SOA', 'SRV', 'TXT']
  const modes = [
    { value: 'tunnel', text: i18n.t('Through the server\'s tunnel') },
    { value: 'packetfence', text: i18n.t('As PacketFence resolves') }
  ]

  // The DNS servers of this connector, identified as the derived
  // config::DnsConnectors namespace does: "<connector>:<ip>:<port>".
  const servers = computed(() => ((form.value || {}).dns_servers || [])
    .filter(s => s && s.ip)
    .map(s => ({ ...s, entryId: `${props.id}:${s.ip}:${s.port || 53}` }))
  )
  const serverOptions = computed(() => servers.value.map(s => ({
    value: s.entryId,
    text: `${s.ip}:${s.port || 53}${(s.domains && s.domains.length) ? ' (' + s.domains.join(', ') + ')' : ''}`
  })))
  watch(servers, () => {
    if (!serverId.value || !servers.value.find(s => s.entryId === serverId.value))
      serverId.value = servers.value.length ? servers.value[0].entryId : null
  }, { immediate: true })

  const selectedServer = computed(() => servers.value.find(s => s.entryId === serverId.value) || null)
  const firstDomain = computed(() => {
    const s = selectedServer.value
    return (s && s.domains && s.domains.length) ? s.domains[0] : null
  })

  const doLookup = (qname, qtype, qmode) => {
    isLoading.value = true
    result.value = null
    api.dnsLookup({ dns_connector_id: serverId.value, name: qname, type: qtype, mode: qmode }).then(response => {
      result.value = response
    }).catch(error => {
      const { response: { data: { message = '' } = {} } = {} } = error
      result.value = {
        reachable: false,
        error: message || i18n.t('Request failed.'),
        name: qname,
        type: qtype,
        mode: qmode,
        connector_id: '-',
        pfconnector_port: '-',
        dns_server: '-'
      }
    }).finally(() => {
      isLoading.value = false
    })
  }

  const lookup = () => doLookup(name.value, type.value, mode.value)

  // Quick server test: ask it for the SOA of the first domain it serves.
  const testServer = () => {
    name.value = firstDomain.value
    type.value = 'SOA'
    doLookup(firstDomain.value, 'SOA', mode.value)
  }

  const alertVariant = computed(() => {
    if (!result.value)
      return 'secondary'
    if (!result.value.reachable)
      return 'danger'
    return (result.value.rcode === 'NOERROR') ? 'success' : 'warning'
  })

  const resultHeadline = computed(() => {
    if (!result.value)
      return ''
    if (!result.value.reachable)
      return i18n.t('No response: {error}', { error: result.value.error || i18n.t('timeout') })
    if (result.value.rcode === 'NOERROR')
      return i18n.t('Success ({rcode})', { rcode: result.value.rcode })
    return i18n.t('Server responded with {rcode}', { rcode: result.value.rcode })
  })

  return {
    name,
    type,
    mode,
    modes,
    serverId,
    serverOptions,
    recordTypes,
    result,
    isLoading,
    firstDomain,
    lookup,
    testServer,
    alertVariant,
    resultHeadline
  }
}

// @vue/component
export default {
  name: 'the-dns-test',
  inheritAttrs: false,
  props,
  setup
}
</script>
