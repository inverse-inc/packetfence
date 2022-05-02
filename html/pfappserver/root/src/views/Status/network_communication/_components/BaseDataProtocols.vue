<template>
  <b-card no-body>
    <b-card-header>
      Protocols
    </b-card-header>
    <b-tabs small>
      <b-tab v-for="protocol in uniqueProtocols" :key="protocol.proto">
        <template #title>
          {{ protocol.proto }} <b-badge pill variant="primary" class="ml-1">{{ protocol.num }}</b-badge>
        </template>

        <pre>{{ uniqueProtocolPortsPerDevice[protocol.proto] }}</pre>

      </b-tab>
    </b-tabs>

    <pre>{{ {data} }}</pre>


  </b-card>
</template>
<script>
const components = {}

const props = {
  data: {
    type: Array
  }
}

import { computed, ref, toRefs } from '@vue/composition-api'

const setup = (props) => {

  const {
    data
  } = toRefs(props)

  const uniqueProtocols = computed(() => {
    const assoc = data.value
      .reduce((unique, item) => {
        unique[item.proto] = (unique[item.proto] || 0) + 1
        return unique
      }, {})
      return Object.keys(assoc)
        .sort((a,b) => a.localeCompare(b))
        .map(proto => {
          return {
            proto,
            num: assoc[proto]
          }
        })
  })

  const uniqueProtocolPortsPerDevice = computed(() => {
    return data.value
      .reduce((unique, item) => {
        const { proto, port, host, mac } = item
        if (!(proto in unique))
          unique[proto] = {}
        if (!(port in unique[proto]))
          unique[proto][port] = {}
        if (!(mac in unique[proto][port]))
          unique[proto][port][mac] = 1
        else
          unique[proto][port][mac]++
        return unique
      }, {})
  })

  return {
    uniqueProtocols,
    uniqueProtocolPortsPerDevice
  }
}



// @vue/component
export default {
  name: 'base-data-protocols',
  components,
  props,
  setup
}
</script>