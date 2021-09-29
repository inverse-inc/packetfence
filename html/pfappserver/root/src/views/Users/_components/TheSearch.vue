<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Search Users') }}
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
            <icon class="position-absolute mt-1" name="ban"></icon>
            <span class="ml-4">{{ $t('Close Security Event') }}</span>
          </b-dropdown-item>
          <b-dropdown-item @click="onBulkRegister">
            <icon class="position-absolute mt-1" name="plus-circle"></icon>
            <span class="ml-4">{{ $t('Register') }}</span>
          </b-dropdown-item>
          <b-dropdown-item @click="onBulkDeregister">
            <icon class="position-absolute mt-1" name="minus-circle"></icon>
            <span class="ml-4">{{ $t('Deregister') }}</span>
          </b-dropdown-item>
          <b-dropdown-item @click="onBulkReevaluateAccess">
            <icon class="position-absolute mt-1" name="sync"></icon>
            <span class="ml-4">{{ $t('Reevaluate Access') }}</span>
          </b-dropdown-item>
          <b-dropdown-item @click="onBulkRefreshFingerbank">
            <icon class="position-absolute mt-1" name="retweet"></icon>
            <span class="ml-4">{{ $t('Refresh Fingerbank') }}</span>
          </b-dropdown-item>
          <b-dropdown-item @click="onBulkDelete">
            <icon class="position-absolute mt-1" name="trash-alt"></icon>
            <span class="ml-4">{{ $t('Delete') }}</span>
          </b-dropdown-item>
          <b-dropdown-divider></b-dropdown-divider>

          <b-dropdown-header>{{ $t('Apply Role') }}</b-dropdown-header>
          <b-dropdown-item v-for="role in roles" :key="`role-${role.category_id}`" @click="onBulkRole(role)">
            <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
          </b-dropdown-item>
          <b-dropdown-item @click="onBulkRole({category_id: null})" >
            <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Role')">
              <icon class="position-absolute mt-1" name="trash-alt"></icon>
              <span class="ml-4"><em>{{ $t('None') }}</em></span>
            </span>
          </b-dropdown-item>
          <b-dropdown-divider></b-dropdown-divider>

          <b-dropdown-header>{{ $t('Apply Bypass Role') }}</b-dropdown-header>
          <b-dropdown-item v-for="role in roles" :key="`bypass_role-${role.category_id}`" @click="onBulkBypassRole(role)">
            <span class="d-block" v-b-tooltip.hover.left.d300.window :title="role.notes">{{role.name}}</span>
          </b-dropdown-item>
          <b-dropdown-item @click="onBulkBypassRole({category_id: null})">
            <span class="d-block" v-b-tooltip.hover.left.d300.window :title="$t('Clear Bypass Role')">
              <icon class="position-absolute mt-1" name="trash-alt"></icon>
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
  const selected = useBootstrapTableSelected(tableRef, items, 'pid')
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
      switch (true) {
        case ['success', 200].includes(item.status): success++
          break
        case ['skipped', 400, 409].includes(item.status): skipped++
          break
        default: failed++
      }
    })
    return { success, skipped, failed }
  }

  const onBulkDelete = () => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkDelete`, { items })
      .then(_items => {
        $store.dispatch('notification/info', {
          message: i18n.tc('Deleted 1 user. | Deleted {userCount} users.', _items.length, { userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkRegister = () => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkRegisterNodes`, { items })
      .then(_items => {
        const nodeCount = _items.reduce((count, item) => (count+item.nodes.length), 0)
        const nodeString = i18n.tc('Registered 1 node | Registered {nodeCount} nodes', nodeCount, { nodeCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', _items.length, { nodeString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkDeregister = () => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkDeregisterNodes`, { items })
      .then(_items => {
        const nodeCount = _items.reduce((count, item) => (count+item.nodes.length), 0)
        const nodeString = i18n.tc('Deregistered 1 node | Deregistered {nodeCount} nodes', nodeCount, { nodeCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', _items.length, { nodeString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkReevaluateAccess = () => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkReevaluateAccess`, { items })
      .then(_items => {
        const nodeCount = _items.reduce((count, item) => (count+item.nodes.length), 0)
        const nodeString = i18n.tc('Reevaluated access on 1 node | Reevaluated access on {nodeCount} nodes', nodeCount, { nodeCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', _items.length, { nodeString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkRefreshFingerbank = () => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkRefreshFingerbank`, { items })
      .then(_items => {
        const nodeCount = _items.reduce((count, item) => (count+item.nodes.length), 0)
        const nodeString = i18n.tc('Refreshed fingerbank on 1 node | Refreshed fingerbank on {nodeCount} nodes', nodeCount, { nodeCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', _items.length, { nodeString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkRole = role => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkApplyRole`, { category_id: role.category_id, items })
      .then(_items => {
        const nodeCount = _items.reduce((count, item) => (count+item.nodes.length), 0)
        const nodeString = i18n.tc('Applied role on 1 node | Applied role on {nodeCount} nodes', nodeCount, { nodeCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', _items.length, { nodeString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkBypassRole = role => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkApplyBypassRole`, { bypass_role_id: role.category_id, items })
      .then(_items => {
        const nodeCount = _items.reduce((count, item) => (count+item.nodes.length), 0)
        const nodeString = i18n.tc('Applied bypass role on 1 node | Applied bypass role on {nodeCount} nodes', nodeCount, { nodeCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{nodeString} for 1 user. | {nodeString} for {userCount} users.', _items.length, { nodeString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkSecurityEvent = securityEvent => {
    const items = selectedItems.value.map(item => item.pid)
    // { vid: securityEvent.vid, items: pids }
    $store.dispatch(`$_users/bulkApplySecurityEvent`, { security_event_id: securityEvent.id, items })
      .then(_items => {
        const securityEventCount = _items.reduce((count, item) => (count+item.security_events.length), 0)
        const securityEventString = i18n.tc('Applied 1 security event | Applied {securityEventCount} security events', securityEventCount, { securityEventCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{securityEventString} for 1 user. | {securityEventString} for {userCount} users.', _items.length, { securityEventString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
      })
  }

  const onBulkCloseSecurityEvent = () => {
    const items = selectedItems.value.map(item => item.pid)
    $store.dispatch(`$_users/bulkCloseSecurityEvents`, { items })
      .then(_items => {
        const securityEventCount = _items.reduce((count, item) => (count+item.security_events.length), 0)
        const securityEventString = i18n.tc('Closed 1 security event | Closed {securityEventCount} security events', securityEventCount, { securityEventCount })
        $store.dispatch('notification/info', {
          message: i18n.tc('{securityEventString} for 1 user. | {securityEventString} for {userCount} users.', _items.length, { securityEventString, userCount: _items.length }),
          ..._statusCounts(_items)
        })
        reSearch()
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
    onBulkDelete,
    onBulkRegister,
    onBulkDeregister,
    onBulkReevaluateAccess,
    onBulkRefreshFingerbank,
    onBulkRole,
    onBulkBypassRole,
    onBulkSecurityEvent,
    onBulkCloseSecurityEvent
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
