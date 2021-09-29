<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Search Nodes') }}
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" />
      <b-table ref="tableRef"
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        @row-clicked="goToItem"
        class="mb-0"
        show-empty
        no-local-sorting
        sort-icon-left
        fixed
        striped
        selectable
        @row-selected="onRowSelected"
      >
        <template #empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
            <base-table-empty :is-loading="isLoading">{{ $t('No results found') }}</base-table-empty>
          </slot>
        </template>
        <template #head(selected)>
          <span @click.stop.prevent="onAllSelected">
            <template v-if="selected.length > 0">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #cell(selected)="{ index, rowSelected }">
          <span @click.stop="onItemSelected(index)">
            <template v-if="rowSelected">
              <icon name="check-square" class="bg-white text-success" scale="1.125" />
            </template>
            <template v-else>
              <icon name="square" class="border border-1 border-gray bg-white text-light" scale="1.125" />
            </template>
          </span>
        </template>
        <template #cell(status)="item">
          <span v-b-tooltip.left.d300 :title="$t('registered')" v-if="item.value === 'reg'">
            <icon name="check-circle" />
          </span>
          <span v-b-tooltip.left.d300 :title="$t('unregistered')" v-else-if="item.value === 'unreg'">
            <icon name="regular/times-circle" />
          </span>
          <span v-b-tooltip.left.d300 :title="$t('pending')" v-else>
            <icon name="regular/dot-circle" />
          </span>
        </template>
        <template #cell(online)="item">
          <span v-b-tooltip.right.d300 :title="$t('on')" v-if="item.value === 'on'">
            <icon name="circle" class="text-success" />
          </span>
          <span v-b-tooltip.right.d300 :title="$t('off')" v-else-if="item.value === 'off'">
            <icon name="circle" class="text-danger" />
          </span>
          <span v-b-tooltip.right.d300 :title="$t('unknown')" v-else>
            <icon name="question-circle" class="text-warning" />
          </span>
        </template>
        <template #cell(mac)="item">
          <mac v-text="item.value" />
        </template>
        <template #cell(pid)="item">
          <b-button variant="link" :to="{ name: 'user', params: { pid: item.value } }">{{ item.value }}</b-button>
        </template>
        <template #cell(device_score)="item">
          <icon-score :score="item.value" />
        </template>
        <template #head(buttons)>
          <base-search-input-columns
            :disabled="isLoading"
            :value="columns"
            @input="setColumns"
          />
        </template>
        <template #cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Node?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
          </span>
        </template>
      </b-table>
      <b-container fluid v-if="selected.length"
        class="mt-3 p-0">
        <b-dropdown variant="outline-primary" toggle-class="text-decoration-none" class="mb-3" no-flip>
          <template #button-content>
            {{ $t('{num} selected', { num: selected.length }) }}
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
        </b-dropdown>
      </b-container>
    </div>

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
  </b-card>
</template>

<script>
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
} from '@/components/new/'
import IconScore from '@/components/IconScore'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty,
  IconScore
}

import { computed, onMounted, ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import i18n from '@/utils/locale'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'

const setup = (props, context) => {

  const search = useSearch()
  const {
    reSearch
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const { root: { $router, $store } = {} } = context

  onMounted(() => {
    $store.dispatch('config/getRoles')
    $store.dispatch('config/getSecurityEvents')
  })
  const roles = computed(() => $store.state.config.roles)
  const security_events = computed(() => $store.getters['config/sortedSecurityEvents'].filter(securityEvent => securityEvent.enabled === 'Y'))

  const {
    deleteItem
  } = useStore($store)

  const router = useRouter($router)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items, 'mac')
  const {
    selectedItems,
  } = selected

  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
  }

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
        reSearch()
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
        reSearch()
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
        reSearch()
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
        reSearch()
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
        reSearch()
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
        reSearch()
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
        reSearch()
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
        reSearch()
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
        reSearch()
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
    useSearch,
    tableRef,
    ...router,
    ...selected,
    ...toRefs(search),

    roles,
    security_events,

    onRemove,
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

    showBypassVlanModal,
    bypassVlanString,
    onBulkBypassVlan
  }
}

// @vue/component
export default {
  name: 'the-search',
  inheritAttrs: false,
  components,
  setup
}
</script>
