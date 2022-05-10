<template>
  <b-card no-body>
    <b-card-header>
      Flows
    </b-card-header>
    <pre>{{ {linkDeviceProtocol, linkProtocolHost, uniqueDevices, uniqueProtocols, uniqueHosts} }}</pre>
  </b-card>
</template>
<script>
const components = {}

const props = {
  items: {
    type: Array
  }
}

import { computed, toRefs } from '@vue/composition-api'

const setup = (props) => {

  const {
    items
  } = toRefs(props)

  const uniqueDevices = computed(() => {
    return items.value
      .reduce((unique, item) => {
        unique[item.mac] = (unique[item.mac] || 0) + 1
        return unique
      }, {})
  })

  const uniqueProtocols = computed(() => {
    return items.value
      .reduce((unique, item) => {
        const protocol = `${item.proto}/${item.port}`
        unique[protocol] = (unique[protocol] || 0) + 1
        return unique
      }, {})
  })

  const uniqueHosts = computed(() => {
    return items.value
      .reduce((unique, item) => {
        unique[item.host] = (unique[item.host] || 0) + 1
        return unique
      }, {})
  })

  const linkDeviceProtocol = computed(() => {
    const assoc = items.value
      .reduce((links, item) => {
        const { mac, proto, port } = item
        const protocol = `${proto}/${port}`
        const key = `${mac}/${protocol}`
        links[key] = {
          mac,
          protocol,
          num: ((links[key]) ? links[key].num + 1 : 1)
        }
        return links
      }, {})
    return Object.values(assoc)
  })

  const linkProtocolHost = computed(() => {
    const assoc = items.value
      .reduce((links, item) => {
        const { host, proto, port } = item
        const protocol = `${proto}/${port}`
        const key = `${protocol}/${host}`
        links[key] = {
          host,
          protocol,
          num: ((links[key]) ? links[key].num + 1 : 1)
        }
        return links
      }, {})
    return Object.values(assoc)
  })

  return {
    uniqueDevices,
    uniqueProtocols,
    uniqueHosts,

    linkDeviceProtocol,
    linkProtocolHost,

  }
}

// @vue/component
export default {
  name: 'base-data-flows',
  components,
  props,
  setup
}
</script>