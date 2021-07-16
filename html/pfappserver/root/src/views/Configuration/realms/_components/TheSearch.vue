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
        <base-button-service
          service="radiusd-auth" restart start stop
          class="ml-1" />
      </base-search>

      <b-card v-for="(tenant, index) in tenantsRealms" :key="tenant.id"
        :class="{ 'mt-3': index > 0 }">
        <h4 class="mb-3">{{ tenant.name }}</h4>
        <b-button variant="outline-primary" @click="goToNew({ tenantId: tenant.id })">{{ $t('New Realm') }}</b-button>
        <the-table class="mt-3" :tenantId="tenant.id"
          :isLoading="isLoading"
          :items="tenant.items"
          :columns="columns"
          :visibleColumns="visibleColumns"
          @reSearch="reSearch"
          @setColumns="setColumns"
        />
      </b-card>
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

import { computed, toRefs } from '@vue/composition-api'
import { useRouter, useSearch } from '../_composables/useCollection'

const setup = (props, context) => {

  const { root: { $router, $store } = {} } = context

  const router = useRouter($router)

  const search = useSearch()
  const {
    items
  } = toRefs(search)

  const singleTenant = computed(() => $store.state.session.tenant)
  const tenants = computed(() => ((singleTenant.value)
    ? $store.state.session.tenants.filter(tenant => +tenant.id === +singleTenant.value.id) // single-tenant mode
    : $store.state.session.tenants // multi-tenant mode
  ))
  const tenantsRealms = computed(() => {
    return tenants.value.map(tenant => {
      return { ...tenant, items: items.value.filter(item => +item.tenant_id === +tenant.id ) }
    })
  })

  return {
    useSearch,
    ...router,
    ...toRefs(search),
    tenantsRealms
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
