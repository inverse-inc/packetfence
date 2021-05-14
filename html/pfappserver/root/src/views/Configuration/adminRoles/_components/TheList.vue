<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-3">
        {{ $t('Admin Roles') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_admin_access" />
      </h4>
      <p class="mb-0" v-t="'Define roles with specific access rights to the Web administration interface. Roles are assigned to users depending on their authentication source.'"></p>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" :to="{ name: 'newAdminRole' }">{{ $t('New Admin Role') }}</b-button>
      </base-search>
      <b-table
        :busy="isLoading"
        :hover="items.length > 0"
        :items="items"
        :fields="visibleColumns"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @sort-changed="setSort"
        @row-clicked="goToItem"
        show-empty

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
        <template v-slot:head(buttons)>
          <base-search-input-columns
            v-model="columns"
            :disabled="isLoading"
          />
        </template>
        <template v-slot:cell(buttons)="{ item }">
          <span class="float-right text-nowrap text-right">
            <base-button-confirm v-if="!item.not_deletable"
              size="sm" variant="outline-danger" class="my-1 mr-1" reverse
              :disabled="isLoading"
              :confirm="$t('Delete Role?')"
              @click="onRemove(item.id)"
            >{{ $t('Delete') }}</base-button-confirm>
            <b-button
              size="sm" variant="outline-primary" class="mr-1"
              @click.stop.prevent="goToClone(item)"
            >{{ $t('Clone') }}</b-button>
          </span>
        </template>
      </b-table>
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  pfEmptyTable
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useSearch, useRouter } from '../_composables/useCollection'

const setup = (props, context) => {

  const search = useSearch()
  const {
    $id: storeId,
    reSearch
  } = search

console.log('1', {storeId, search})

  const { root: { $router, $store } = {} } = context

  const {
    goToItem,
    goToClone
  } = useRouter($router)

  const onRemove = id => {
    $store.dispatch('$_admin_roles/deleteAdminRole', id)
      .then(() => {
        reSearch()
      })
  }

  return {
    useSearch,
    goToItem,
    goToClone,
    onRemove,

    ...toRefs(search)
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
