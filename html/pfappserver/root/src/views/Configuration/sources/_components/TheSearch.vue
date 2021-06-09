<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-flex align-items-center">
        {{ $t('Authentication Sources') }}
        <base-button-help class="text-black-50 ml-1" url="PacketFence_Installation_Guide.html#_authentication_sources" />
      </h4>
      <p v-t="'Define the authentication sources to let users access the captive portal or the admin Web interface.'"></p>
      <p class="mb-0" v-t="'Each connection profile must be associated with one or multiple authentication sources while 802.1X connections use the ordered internal sources to determine which role to use. External sources are never used with 802.1X connections.'"></p>
    </b-card-header>
    <div class="card-body">
      <base-search :use-search="useSearch" />

      <b-card>
        <h4 class="mb-3">{{ $t('Internal Sources') }}</h4>
        <b-dropdown :text="$t('New internal source')" variant="outline-primary">
          <b-dropdown-item v-for="(text, sourceType) in internalTypes" :key="sourceType"
            :to="{ name: 'newAuthenticationSource', params: { sourceType } }"
          >{{ text }}</b-dropdown-item>
        </b-dropdown>
        <the-table class="mt-3"
          :isLoading="isLoading"
          :items="internalItems"
          :columns="columns"
          :visibleColumns="visibleColumns"
          @reSearch="reSearch"
          @setColumns="setColumns"
        />
      </b-card>

      <b-card class="mt-3">
        <h4 class="mb-3">{{ $t('External Sources') }}</h4>
        <b-dropdown :text="$t('New external source')" variant="outline-primary">
          <b-dropdown-item v-for="(text, sourceType) in externalTypes" :key="sourceType"
            :to="{ name: 'newAuthenticationSource', params: { sourceType } }"
          >{{ text }}</b-dropdown-item>
        </b-dropdown>
        <the-table class="mt-3"
          :isLoading="isLoading"
          :items="externalItems"
          :columns="columns"
          :visibleColumns="visibleColumns"
          @reSearch="reSearch"
          @setColumns="setColumns"
        />
      </b-card>

      <b-card class="mt-3">
        <h4 class="mb-3">{{ $t('Exclusive Sources') }}</h4>
        <b-dropdown :text="$t('New exclusive source')" variant="outline-primary">
          <b-dropdown-item v-for="(text, sourceType) in exclusiveTypes" :key="sourceType"
            :to="{ name: 'newAuthenticationSource', params: { sourceType } }"
          >{{ text }}</b-dropdown-item>
        </b-dropdown>
        <the-table class="mt-3"
          :isLoading="isLoading"
          :items="exclusiveItems"
          :columns="columns"
          :visibleColumns="visibleColumns"
          @reSearch="reSearch"
          @setColumns="setColumns"
        />
      </b-card>

      <b-card class="mt-3">
        <h4 class="mb-3">{{ $t('Billing Sources') }}</h4>
        <b-dropdown :text="$t('New billing source')" variant="outline-primary">
          <b-dropdown-item v-for="(text, sourceType) in billingTypes" :key="sourceType"
            :to="{ name: 'newAuthenticationSource', params: { sourceType } }"
          >{{ text }}</b-dropdown-item>
        </b-dropdown>
        <the-table class="mt-3"
          :isLoading="isLoading"
          :items="billingItems"
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
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable
} from '@/components/new/'
import pfEmptyTable from '@/components/pfEmptyTable'
import TheTable from './TheTable'

const components = {
  BaseButtonConfirm,
  BaseButtonHelp,
  BaseSearch,
  BaseSearchInputColumns,
  BaseTableSortable,
  pfEmptyTable,
  TheTable
}

import { computed, toRefs } from '@vue/composition-api'
import { useSearch } from '../_composables/useCollection'
import { internalTypes, externalTypes, exclusiveTypes, billingTypes } from '../config'

const setup = () => {

  const search = useSearch()
  const {
    items
  } = toRefs(search)

  const internalItems = computed(() => items.value.filter(s => s.id !== 'local' && s.class === 'internal'))
  const externalItems = computed(() => items.value.filter(s => s.id !== 'local' && s.class === 'external'))
  const exclusiveItems = computed(() => items.value.filter(s => s.id !== 'local' && s.class === 'exclusive'))
  const billingItems = computed(() => items.value.filter(s => s.id !== 'local' && s.class === 'billing'))

  return {
    useSearch,
    ...toRefs(search),

    internalTypes,
    internalItems,

    externalTypes,
    externalItems,

    exclusiveTypes,
    exclusiveItems,

    billingTypes,
    billingItems,
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
