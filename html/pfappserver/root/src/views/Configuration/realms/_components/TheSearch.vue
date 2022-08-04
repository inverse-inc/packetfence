<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center mb-0">
        {{ $t('Realms') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_default_domain_configuration" />
      </h4>
    </b-card-header>
    <div class="card-body">
      <div class="alert alert-warning">{{ $t(`Any changes to the realms requires to restart radiusd-auth`) }}</div>
      <base-search :use-search="useSearch">
        <b-button variant="outline-primary" @click="goToNew">{{ $t('New Realm') }}</b-button>
        <base-button-service
          service="radiusd-auth" restart start stop
          class="ml-1" />
      </base-search>
      <the-table class="mt-3"
        :isLoading="isLoading"
        :items="items"
        :columns="columns"
        :visibleColumns="visibleColumns"
        @reSearch="reSearch"
        @setColumns="setColumns"
      />
    </div>
  </b-card>
</template>
<script>
import {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable
} from '@/components/new/'
import TheTable from './TheTable'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseButtonService,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable,
  TheTable
}

import { toRefs } from '@vue/composition-api'
import { useRouter, useSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $router } = {} } = context

  const router = useRouter($router)

  const search = useSearch()

  return {
    useSearch,
    ...router,
    ...toRefs(search)
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
