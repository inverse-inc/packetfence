<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Roles') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_introduction_to_role_based_access_control" />
      </h4>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New Role') }}</b-button>
      </base-search>
      <b-table ref="tableRef" class="the-tree-list mb-0"
        :busy="isLoading"
        :hover="itemsTree.length > 0"
        :items="itemsTree"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        @row-clicked="goToItem"
        borderless
        show-empty
        small
        no-local-sorting
        response
        sort-icon-left
        fixed
        striped
        selectable
        @row-selected="onRowSelected"
      >
        <template v-slot:empty>
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
              :confirm="$t('Delete Tenant?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone(item)"
            >{{ $t('Clone') }}</b-button>
            <b-button v-if="isInline"
              size="sm" variant="outline-primary" class="mr-1"
              :to="trafficShapingRoute(item.id)"
            >{{ $t('Traffic Shaping') }}</b-button>
          </span>
        </template>
        <template #cell(id)="{ item }">
          <icon v-for="(icon, i) in item._tree" :key="i"
            v-bind="icon" />
          <b-link v-if="item.children"
            :class="(collapsedNodes.includes(item.id)) ? 'text-danger' : 'text-secondary'"
             @click.stop="onToggleNode(item.id)"
          >
            <icon v-bind="item._icon" />
          </b-link>
          <icon v-else
            v-bind="item._icon" />
          {{ item.id }}
        </template>
      </b-table>
      <b-container fluid v-if="selected.length"
        class="mt-3 p-0">
        <b-dropdown variant="outline-primary" toggle-class="text-decoration-none">
          <template #button-content>
            {{ $t('{num} selected', { num: selected.length }) }}
          </template>
          <b-dropdown-item @click="onBulkExport">{{ $t('Export to CSV') }}</b-dropdown-item>
        </b-dropdown>
      </b-container>
    </div>

    <b-modal v-model="showDeleteErrorsModal" size="lg"
      centered lazy scrollable
      :no-close-on-backdrop="isLoading"
      :no-close-on-esc="isLoading"
    >
      <template v-slot:modal-title>
        {{ $t('Delete Role') }} <b-badge variant="secondary">{{ deleteId }}</b-badge>
      </template>
      <b-media no-body class="alert alert-danger">
        <template v-slot:aside>
          <icon name="exclamation-triangle" scale="2"/>
        </template>
        <div class="mx-2">{{ $t('The role could not be deleted. Either manually handle the following errors and try again, or re-reassign the resources to another existing role.') }}</div>
      </b-media>
      <h5>{{ $t('Role is still in use for:') }}</h5>
      <b-row v-for="error in deleteErrors" :key="error.reason">
        <b-col cols="auto" class="mr-auto">{{ reasons[error.reason] }}</b-col>
        <b-col cols="auto">{{ error.reason }}</b-col>
      </b-row>
      <template v-slot:modal-footer>
        <b-row class="w-100">
          <b-col cols="auto" class="mr-auto pl-0">
            <b-form-select size="sm" class="d-inline"
              v-model="reassignRole"
              :options="reassignableRoles"
            />
            <b-button size="sm" class="ml-1" variant="outline-primary"  @click="reAssign()" :disabled="isLoading">{{ $i18n.t('Reassign Role') }}</b-button>
          </b-col>
          <b-col cols="auto" class="pr-0">
            <b-button variant="secondary"  @click="showDeleteErrorsModal = false" :disabled="isLoading">{{ $i18n.t('Fix Manually') }}</b-button>
          </b-col>
        </b-row>
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

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableEmpty
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useBootstrapTableSelected } from '@/composables/useBootstrap'
import { useTableColumnsItems } from '@/composables/useCsv'
import { useDownload } from '@/composables/useDownload'
import { useSearch, useStore, useRouter } from '../_composables/useCollection'
import { useNodeInheritance } from '../_composables/useNodeInheritance'
import { reasons } from '../config'

const setup = (props, context) => {

  const search = useSearch()
  const {
    reSearch,
    sortBy,
    sortDesc
  } = search
  const {
    items,
    visibleColumns
  } = toRefs(search)

  const { root: { $router, $store } = {} } = context

  const {
    deleteItem
  } = useStore($store)

  const router = useRouter($router)

  const tableRef = ref(null)
  const selected = useBootstrapTableSelected(tableRef, items)
  const {
    selectedItems
  } = selected

  const onBulkExport = () => {
    const filename = `${$router.currentRoute.path.slice(1).replace('/', '-')}-${(new Date()).toISOString()}.csv`
    const csv = useTableColumnsItems(visibleColumns.value, selectedItems.value)
    useDownload(filename, csv, 'text/csv')
  }

  const deleteId = ref(null)
  const deleteErrors = ref(null)
  const showDeleteErrorsModal = ref(false)
  const onRemove = id => {
    deleteItem({ id })
      .then(() => reSearch())
      .catch(error => {
        const { response: { data: { errors = [] } = {} } = {} } = error
        if (errors.length) {
          deleteId.value = id
          deleteErrors.value = errors
          showDeleteErrorsModal.value = true
        }
      })
  }

  const reassignRole = ref('default')
  const reassignableRoles = computed(() => {
    return items.value
      .filter(role => role.id !== deleteId.value)
      .map(role => ({ text: role.id, value: role.id }))
  })
  const reAssign = () => {
    $store.dispatch('$_roles/reassignRole', { from: deleteId.value, to: reassignRole.value })
      .then(() => {
        showDeleteErrorsModal.value = false
        // cascade delete
        onRemove(deleteId.value)
      })
  }

  const _trafficShapingPolicies = ref([])
  $store.dispatch('$_traffic_shaping_policies/all')
    .then(response => {
      _trafficShapingPolicies.value = response.map(policy => policy.id)
    })

  const trafficShapingRoute = id => {
    return (_trafficShapingPolicies.value.includes(id))
      ? { name: 'traffic_shaping', params: { id } } // exists
      : { name: 'newTrafficShaping', params: { role: id } } // not exists
  }

  const isInline = computed(() => $store.getters['system/isInline'])

  const {
    collapsedNodes,
    clearExpandedNodes,
    onToggleNode,
    itemsTree,
  } = useNodeInheritance(items, sortBy, sortDesc)

  return {
    useSearch,
    tableRef,
    onRemove,
    onBulkExport,
    ...router,
    ...selected,
    ...toRefs(search),
    deleteId,
    deleteErrors,
    showDeleteErrorsModal,
    reassignRole,
    reassignableRoles,
    reasons,
    reAssign,
    trafficShapingRoute,
    isInline,

    collapsedNodes,
    clearExpandedNodes,
    onToggleNode,
    itemsTree
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

<style lang="scss">
$table-cell-height: 2.5 * $spacer !default;

.the-tree-list {
  thead[role="rowgroup"] {
    border-bottom: 1px solid #dee2e6 !important;
  }
  tr[role="row"],
  tr[role="row"] > th[role="columnheader"] {
    cursor: pointer;
    outline-width: 0;
    td[role="cell"] {
      height: $table-cell-height;
      padding: 0 0.3rem;
      word-wrap: nowrap;
      div[variant="link"] {
        line-height: 1em;
      }
    }
    td[aria-colindex="2"] {
      svg.fa-icon:not(.nav-icon) {
        min-width: $table-cell-height;
        height: auto;
        max-height: $table-cell-height/2;
        margin: 0.25rem 0;
      }
      svg.nav-icon {
        height: $table-cell-height;
        color: $gray-500;
      }
    }
  }
  .table-row-disabled {
    opacity: 0.6;
  }
}
</style>