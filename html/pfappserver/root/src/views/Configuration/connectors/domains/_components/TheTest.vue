<template>
  <div class="card mx-3 mb-3 bg-light">
    <div class="card-body">
      <b-row align-v="center" class="mb-2">
        <b-col>
          <h6 class="mb-0">{{ $i18n.t('Test Domain Resolution') }}</h6>
          <small class="text-muted">{{ $i18n.t('The query is sent to the pfdns-connector front-end, which routes it by domain through the connector tunnel — exactly as PacketFence resolves at runtime. Any answer, including NXDOMAIN, proves the routing and the DNS server are working.') }}</small>
        </b-col>
        <b-col cols="auto">
          <b-button size="sm" variant="outline-primary" :disabled="isLoading || !id" @click="testDomain">
            <icon name="stethoscope" class="mr-1" />{{ $i18n.t('Test Domain') }}
          </b-button>
        </b-col>
      </b-row>

      <b-form inline @submit.prevent="lookup">
        <b-form-input v-model="name" class="mr-2 flex-grow-1"
          :placeholder="$i18n.t('FQDN to resolve, e.g. host.') + (id || 'example.com')"
        />
        <b-form-select v-model="type" :options="recordTypes" class="mr-2" />
        <b-button type="submit" variant="primary" :disabled="isLoading || !name">
          <icon v-if="isLoading" name="circle-notch" spin class="mr-1" />{{ $i18n.t('Lookup') }}
        </b-button>
      </b-form>

      <div v-if="result" class="mt-3">
        <b-alert show :variant="alertVariant" class="mb-2">
          <b-row align-v="center">
            <b-col>
              <strong>{{ resultHeadline }}</strong>
              <div class="small">
                {{ $i18n.t('Query') }}: <span class="text-monospace">{{ result.name }} {{ result.type }}</span>
                — {{ $i18n.t('via pfdns-connector front-end') }}
                <span class="text-monospace">{{ result.dns_server }}</span>
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
import { computed, ref } from '@vue/composition-api'
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
  const name = ref('')
  const type = ref('A')
  const result = ref(null)
  const isLoading = ref(false)

  const recordTypes = ['A', 'AAAA', 'CNAME', 'MX', 'NS', 'PTR', 'SOA', 'SRV', 'TXT']

  const doLookup = (qname, qtype) => {
    isLoading.value = true
    result.value = null
    api.lookup({ name: qname, type: qtype, mode: 'packetfence' }).then(response => {
      result.value = response
    }).catch(error => {
      const { response: { data: { message = '' } = {} } = {} } = error
      result.value = {
        reachable: false,
        error: message || i18n.t('Request failed.'),
        name: qname,
        type: qtype,
        dns_server: '-'
      }
    }).finally(() => {
      isLoading.value = false
    })
  }

  const lookup = () => doLookup(name.value, type.value)

  // Quick domain test: ask for the SOA of the domain itself, which the
  // routed DNS server must be able to answer.
  const testDomain = () => {
    name.value = props.id
    type.value = 'SOA'
    doLookup(props.id, 'SOA')
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
    recordTypes,
    result,
    isLoading,
    lookup,
    testDomain,
    alertVariant,
    resultHeadline
  }
}

// @vue/component
export default {
  name: 'the-test',
  inheritAttrs: false,
  props,
  setup
}
</script>
