<template>
  <b-card no-body>
    <b-card-header>
      <div class="float-right">
        <base-input-toggle-advanced-mode
          v-model="advancedMode"
          :disabled="isLoading"
          label-left
        />
      </div>
      <h4 class="mb-0">
        {{ $t('Roles') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_introduction_to_role_based_access_control" />
      </h4>
    </b-card-header>
    <div class="card-body">
      <transition name="fade" mode="out-in">
        <div v-if="advancedMode">
          <b-form @submit.prevent="onSearchAdvanced" @reset.prevent="onSearchReset">
            <base-search-input-advanced
              v-model="conditionAdvanced"
              :disabled="isLoading"
              :fields="fields"
              @reset="onSearchReset"
              @search="onSearchAdvanced"
            />
            <b-container fluid class="text-right mt-3 px-0">
              <b-button class="mr-1" type="reset" variant="secondary" :disabled="isLoading">{{ $t('Clear') }}</b-button>
              <base-button-save-search
                save-search-namespace="roles-advanced"
                v-model="conditionAdvanced"
                :disabled="isLoading"
                @search="onSearchAdvanced"
              />
            </b-container>
          </b-form>
        </div>
        <base-search-input-basic v-else
          save-search-namespace="roles-basic"
          v-model="conditionBasic"
          :disabled="isLoading"
          :placeholder="$t('Search by name or description')"
          @reset="onSearchReset"
          @search="onSearchBasic"
        />
      </transition>
    </div>
    <div class="card-body pt-0">
      <b-row>
        <b-col cols="auto" class="mr-auto mb-3">
          <b-button variant="outline-primary" :to="{ name: 'newRole' }">{{ $t('New Role') }}</b-button>
        </b-col>
      </b-row>
      <b-row align-h="end" align-v="center">
        <b-col>
          <base-search-input-columns
            v-model="columns"
            :disabled="isLoading"
          />
        </b-col>
        <b-col cols="auto">
          <b-container fluid>
            <b-row align-v="center">
              <base-search-input-limit
                v-model="limit"
                size="md"
                :limits="limits"
                :disabled="isLoading"
              />
              <base-search-input-page
                v-model="page"
                :limit="limit"
                :total-rows="totalRows"
                :disabled="isLoading"
              />
              <base-button-export-csv
                class="mb-3" size="md"
                :filename="`${$route.path.slice(1).replace('/', '-')}.csv`"
                :disabled="isLoading"
                :columns="columns" :data="itemsTree"
              />
            </b-row>
          </b-container>
        </b-col>
      </b-row>
      <b-table
        class="the-tree-list"
        :busy="isLoading"
        :hover="itemsTree.length > 0"
        :items="itemsTree"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="onSortChanged"
        @row-clicked="onRowClicked"
        show-empty
        small
        borderless
        responsive
        no-local-sorting
        sort-icon-left
        fixed
        striped
      >
        <template v-slot:empty>
          <slot name="emptySearch" v-bind="{ isLoading }">
              <pf-empty-table :is-loading="isLoading">{{ $t('No results found') }}</pf-empty-table>
          </slot>
        </template>
        <template v-slot:cell(id)="{ item }">
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
        <template v-slot:cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Role?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="onClone(item.id)">{{ $t('Clone') }}</b-button>
            <b-button v-if="isInline" size="sm" variant="outline-primary" class="mr-1" :to="trafficShapingRoute(item.id)">{{ $t('Traffic Shaping') }}</b-button>
          </span>
        </template>
      </b-table>
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
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonExportCsv,
  BaseButtonHelp,
  BaseButtonSaveSearch,
  BaseInputToggleAdvancedMode,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  BaseButtonConfirm,
  BaseButtonExportCsv,
  BaseButtonHelp,
  BaseButtonSaveSearch,
  BaseInputToggleAdvancedMode,
  BaseSearchInputBasic,
  BaseSearchInputAdvanced,
  BaseSearchInputColumns,
  BaseSearchInputLimit,
  BaseSearchInputPage,
  pfEmptyTable
}

import { computed, ref } from '@vue/composition-api'
import { useSearch, useRouter } from '../_composables/useCollection'
import { useNodeInheritance } from '../_composables/useNodeInheritance'
import { reasons } from '../config'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const search = useSearch(props, context)
  const {
    reSearch,
    items,
    sortBy,
    sortDesc,
    onSearchBasic: _onSearchBasic,
    onSearchAdvanced: _onSearchAdvanced,
    onSearchReset: _onSearchReset
  } = search

  const onSearchBasic = () => {
    clearExpandedNodes()
    return _onSearchBasic()
  }

  const onSearchAdvanced = () => {
    clearExpandedNodes()
    return _onSearchAdvanced()
  }

  const onSearchReset = () => {
    clearExpandedNodes()
    return _onSearchReset()
  }

  const onRowClicked = item => {
    const {
      goToItem
    } = useRouter($router)
    goToItem(item)
  }

  const onClone = id => {
    $router.push({ name: 'cloneRole', params: { id } })
  }

  const deleteId = ref(null)
  const deleteErrors = ref(null)
  const showDeleteErrorsModal = ref(false)
  const onRemove = id => {
    $store.dispatch('$_roles/deleteRole', id)
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
    onSearchBasic,
    onSearchAdvanced,
    onSearchReset,
    onRowClicked,
    onClone,
    onRemove,
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
    itemsTree,

    ...search
  }
}

// @vue/component
export default {
  name: 'the-list',
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
    td[aria-colindex="1"] {
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