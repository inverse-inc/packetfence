<template>
  <div>
    <h6 class="text-secondary">{{ $t('Host interfaces') }}</h6>
    <b-table-simple v-if="interfaces && interfaces.length" small class="mb-1">
      <b-thead>
        <b-tr>
          <b-th>{{ $t('Interface') }}</b-th>
          <b-th>{{ $t('State') }}</b-th>
          <b-th>{{ $t('Addresses') }}</b-th>
        </b-tr>
      </b-thead>
      <b-tbody>
        <b-tr v-for="iface in interfaces" :key="iface.name">
          <b-td class="text-monospace text-nowrap">
            {{ iface.name }}
            <b-badge v-if="iface.main" variant="primary" class="ml-1 align-text-bottom"
              :title="$t('Holds the default route: the connector reaches PacketFence through it. Its own configuration is never changed by the connector; VLAN interfaces can be created on it.')"
            >{{ $t('main') }}</b-badge>
            <b-badge v-if="iface.managed" variant="info" class="ml-1 align-text-bottom"
              :title="$t('VLAN interface created by the connector from the rows below')"
            >{{ $t('connector') }}</b-badge>
          </b-td>
          <b-td>
            <b-badge :variant="iface.up ? 'success' : 'secondary'">{{ iface.up ? $t('up') : $t('down') }}</b-badge>
          </b-td>
          <b-td class="text-monospace">
            <template v-if="iface.addresses && iface.addresses.length">
              <div v-for="address in iface.addresses" :key="address" class="text-nowrap">
                {{ address }}
                <b-badge v-if="isManaged(iface, address)" variant="info" class="ml-1 align-text-bottom"
                  :title="$t('Assigned by the connector from the rows below')"
                >{{ $t('connector') }}</b-badge>
              </div>
            </template>
            <span v-else class="text-muted">{{ $t('none') }}</span>
          </b-td>
        </b-tr>
      </b-tbody>
    </b-table-simple>
    <p v-else class="text-muted mb-1">{{ $t('The interfaces of the connector host are listed here once the connector is connected.') }}</p>
    <small class="text-muted d-block">{{ $t('Live view of the interfaces of the connector host, loopback and container interfaces excluded; with high availability, of the active host. Addresses without the connector badge were configured by the operating system or by hand and are never touched by the connector.') }}</small>
  </div>
</template>
<script>
const props = {
  interfaces: {
    type: Array,
    default: () => []
  }
}

const setup = () => {
  const isManaged = (iface, address) => (iface.managed_addresses || []).includes(address)
  return {
    isManaged
  }
}

// @vue/component
export default {
  name: 'the-host-interfaces',
  props,
  setup
}
</script>
