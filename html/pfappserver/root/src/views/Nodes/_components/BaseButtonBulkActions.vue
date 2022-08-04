<template>
  <b-dropdown variant="outline-primary" toggle-class="text-decoration-none" no-flip>
    <template #button-content>
      <slot name="default">{{ $t('{num} selected', { num: selectedItems.length }) }}</slot>
    </template>
    <b-dropdown-item @click="onBulkExport">
      <icon class="position-absolute mt-1" name="file-export" />
      <span class="ml-4">{{ $t('Export to CSV') }}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkCloseSecurityEvent">
      <icon class="position-absolute mt-1" name="ban" />
      <span class="ml-4">{{ $t('Close Security Event') }}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkRegister">
      <icon class="position-absolute mt-1" name="plus-circle" />
      <span class="ml-4">{{ $t('Register') }}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkDeregister">
      <icon class="position-absolute mt-1" name="minus-circle" />
      <span class="ml-4">{{ $t('Deregister') }}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkReevaluateAccess">
      <icon class="position-absolute mt-1" name="sync" />
      <span class="ml-4">{{ $t('Reevaluate Access') }}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkRestartSwitchport">
      <icon class="position-absolute mt-1" name="retweet" />
      <span class="ml-4">{{ $t('Restart Switchport') }}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkRefreshFingerbank">
      <icon class="position-absolute mt-1" name="retweet" />
      <span class="ml-4">{{ $t('Refresh Fingerbank') }}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="showBypassVlanModal = true">
      <icon class="position-absolute mt-1" name="project-diagram" />
      <span class="ml-4">{{ $t('Apply Bypass VLAN') }}</span>
    </b-dropdown-item>
    <b-dropdown-divider />
    <b-dropdown-header>{{ $t('Apply Role') }}</b-dropdown-header>
    <b-dropdown-item v-for="role in roles" :key="`role-${role.category_id}`" @click="onBulkRole(role)">
      <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkRole({category_id: null})">
      <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Role')">
        <icon class="position-absolute mt-1" name="trash-alt" />
        <span class="ml-4"><em>{{ $t('None') }}</em></span>
      </span>
    </b-dropdown-item>
    <b-dropdown-divider />
    <b-dropdown-header>{{ $t('Apply Bypass Role') }}</b-dropdown-header>
    <b-dropdown-item v-for="role in roles" :key="`bypass_role-${role.category_id}`" @click="onBulkBypassRole(role)">
      <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
    </b-dropdown-item>
    <b-dropdown-item @click="onBulkBypassRole({category_id: null})">
      <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Bypass Role')">
        <icon class="position-absolute mt-1" name="trash-alt" />
        <span class="ml-4"><em>{{ $t('None') }}</em></span>
      </span>
    </b-dropdown-item>
    <template v-if="$can.apply(null, ['read', 'security_events'])">
      <b-dropdown-divider />
      <b-dropdown-header>{{ $t('Apply Security Event') }}</b-dropdown-header>
      <b-dropdown-item v-for="security_event in security_events" :key="`security_event-${security_event.id}`" @click="onBulkSecurityEvent(security_event)" v-b-tooltip.hover.left.d300 :title="security_event.id">
        <span>{{security_event.desc}}</span>
      </b-dropdown-item>
    </template>

    <b-modal v-model="showBypassVlanModal" @shown="$refs.bypassVlanInput.focus()"
      size="sm" centered id="bypassVlanModal" :title="$t('Bulk Apply Bypass VLAN')">
      <b-form-group>
        <b-form-input ref="bypassVlanInput" v-model="bypassVlanString" type="text" :placeholder="$t('Enter a VLAN')" />
        <b-form-text v-t="'Leave empty to clear bypass VLAN.'" />
      </b-form-group>
      <template #modal-footer>
        <b-button variant="secondary" class="mr-1" @click="showBypassVlanModal=false">{{ $t('Cancel') }}</b-button>
        <b-button variant="primary" @click="onBulkBypassVlan">{{ $t('Apply') }}</b-button>
      </template>
    </b-modal>

  </b-dropdown>
</template>
<script>
const props = {
  selectedItems: {
    type: Array
  },
  visibleColumns: {
    type: Array
  }
}

import { computed, onMounted, ref, toRefs } from '@vue/composition-api'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import i18n from '@/utils/locale'

const setup = (props, context) => {

  const {
    selectedItems,
    visibleColumns
  } = toRefs(props)

  const { emit, root: { $router, $store } = {} } = context

  onMounted(() => {
    $store.dispatch('config/getRoles')
    $store.dispatch('config/getSecurityEvents')
  })
  const roles = computed(() => $store.state.config.roles)
  const security_events = computed(() => $store.getters['config/sortedSecurityEvents'].filter(securityEvent => securityEvent.enabled === 'Y'))

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const _statusCounts = items => {
    let success = 0
    let skipped = 0
    let failed = 0
    items.forEach(item => {
      switch (item.status) {
        case 'success': success++
          break
        case 'skipped': skipped++
          break
        default: failed++
      }
    })
    return { success, skipped, failed }
  }

  const onBulkCloseSecurityEvent = () => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkCloseSecurityEvents`, { items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Closed security events on 1 node. | Closed security events on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkRegister = () => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkRegisterNodes`, { items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Registered 1 node. | Registered {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkDeregister = () => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkDeregisterNodes`, { items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Deregistered 1 node. | Deregistered {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkReevaluateAccess = () => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkReevaluateAccess`, { items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Reevaluated access on 1 node. | Reevaluated access on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkRestartSwitchport = () => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkRestartSwitchport`, { items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Restarted switch port on 1 node. | Restarted switch port on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkRefreshFingerbank = () => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkRefreshFingerbank`, { items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Refreshed fingerbank on 1 node. | Refreshed fingerbank on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkRole = role => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkApplyRole`, { category_id: role.category_id, items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Applied role on 1 node. | Applied role on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkBypassRole = role => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkApplyBypassRole`, { bypass_role_id: role.category_id, items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Applied bypass role on 1 node. | Applied bypass role on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }

  const onBulkSecurityEvent = securityEvent => {
    const items = selectedItems.value.map(item => item.mac)
    $store.dispatch(`$_nodes/bulkApplySecurityEvent`, { security_event_id: securityEvent.id, items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Applied security event on 1 node. | Applied security event on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
        emit('bulk', _items)
      })
  }


  const showBypassVlanModal = ref(false)
  const bypassVlanString = ref(null)
  const onBulkBypassVlan = () => {
    showBypassVlanModal.value = false
    const items = selectedItems.value.map(item => item.mac)
    const bypassVlan = (bypassVlanString.value) ? bypassVlanString.value : null
    $store.dispatch(`$_nodes/bulkApplyBypassVlan`, { bypass_vlan: bypassVlan, items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: this.$i18n.tc('Applied bypass VLAN on 1 node. | Applied bypass VLAN on {nodeCount} nodes.', _items.length, { nodeCount: _items.length }),
          ..._statusCounts(_items)
        })
      })
  }

  return {
    roles,
    security_events,

    onBulkExport,
    onBulkCloseSecurityEvent,
    onBulkRegister,
    onBulkDeregister,
    onBulkReevaluateAccess,
    onBulkRestartSwitchport,
    onBulkRefreshFingerbank,
    onBulkRole,
    onBulkBypassRole,
    onBulkSecurityEvent,
    onBulkBypassVlan,
    showBypassVlanModal,
    bypassVlanString
  }
}

// @vue/component
export default {
  name: 'base-button-bulk-actions',
  inheritAttrs: false,
  props,
  setup
}
</script>

<style lang="scss">
  // remove bootstrap background color
  .b-table-top-row {
    background: none !important;
  }
</style>