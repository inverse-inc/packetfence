<template>
  <div class="mt-3">
    <div class="d-flex justify-content-between align-items-center mb-3">
      <span>{{ $t('{count} devices discovered', { count: devices.length }) }}</span>
      <div>
        <b-button
          v-if="devices.length > 0"
          variant="outline-danger"
          size="sm"
          :disabled="isLoading"
          @click="$emit('clear')"
        >{{ $t('Clear All') }}</b-button>
      </div>
    </div>

    <b-table
      :items="devices"
      :fields="visibleColumns"
      :busy="isLoading"
      :sort-by.sync="sortBy"
      :sort-desc.sync="sortDesc"
      class="mb-0"
      show-empty
      sort-icon-left
      striped
      hover
    >
      <template #empty>
        <div class="text-center text-muted py-5">
          <icon name="search" scale="3" class="mb-3" />
          <p class="mb-0">{{ $t('No devices discovered yet. Select a network and start scanning.') }}</p>
        </div>
      </template>

      <template #head(buttons)>
        <base-search-input-columns
          :disabled="isLoading"
          :value="columns"
          @input="setColumns"
        />
      </template>

      <template #cell(ip)="{ value }">
        <code>{{ value }}</code>
      </template>

      <template #cell(vendor)="{ value }">
        <span v-if="value">{{ value }}</span>
        <span v-else class="text-muted">-</span>
      </template>

      <template #cell(driver)="{ value }">
        <span v-if="value">{{ value }}</span>
        <span v-else class="text-muted">{{ $t('Unknown') }}</span>
      </template>

      <template #cell(os)="{ value }">
        <span v-if="value">{{ value }}</span>
        <span v-else class="text-muted">-</span>
      </template>

      <template #cell(version)="{ value }">
        <span v-if="value">{{ value }}</span>
        <span v-else class="text-muted">-</span>
      </template>

      <template #cell(system)="{ value }">
        <span v-if="value" class="text-truncate d-inline-block" style="max-width: 300px;" :title="value">
          {{ value }}
        </span>
        <span v-else class="text-muted">-</span>
      </template>

      <template #cell(oid)="{ value }">
        <code v-if="value" class="text-truncate d-inline-block" style="max-width: 200px;" :title="value">
          {{ value }}
        </code>
        <span v-else class="text-muted">-</span>
      </template>

      <template #cell(credential)="{ item }">
        <span v-if="item.credential">
          {{ item.credential.type }}
          <small v-if="item.credential.snmp_read" class="text-muted">
            ({{ item.credential.snmp_read }})
          </small>
        </span>
        <span v-else class="text-muted">-</span>
      </template>

      <template #cell(network)="{ value }">
        <code v-if="value">{{ value }}</code>
        <span v-else class="text-muted">-</span>
      </template>

      <template #cell(buttons)="{ item }">
        <span class="float-right text-nowrap">
          <b-button
            size="sm"
            variant="outline-danger"
            :disabled="isLoading"
            @click.stop="$emit('remove', item.ip)"
          >{{ $t('Remove') }}</b-button>
        </span>
      </template>
    </b-table>
  </div>
</template>

<script>
import { computed, ref } from '@vue/composition-api'
import i18n from '@/utils/locale'
import {
  BaseSearchInputColumns
} from '@/components/new/'

const components = {
  BaseSearchInputColumns
}

const props = {
  devices: {
    type: Array,
    default: () => ([])
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

const setup = () => {
  const sortBy = ref('ip')
  const sortDesc = ref(false)

  const columns = ref([
    {
      key: 'ip',
      label: i18n.t('IP Address'),
      sortable: true,
      class: 'text-nowrap',
      visible: true,
      locked: true
    },
    {
      key: 'vendor',
      label: i18n.t('Vendor'),
      sortable: true,
      visible: true
    },
    {
      key: 'driver',
      label: i18n.t('Driver'),
      sortable: true,
      visible: true
    },
    {
      key: 'os',
      label: i18n.t('OS'),
      sortable: true,
      visible: true
    },
    {
      key: 'version',
      label: i18n.t('Version'),
      sortable: true,
      visible: true
    },
    {
      key: 'system',
      label: i18n.t('System'),
      sortable: true,
      visible: true
    },
    {
      key: 'oid',
      label: i18n.t('OID'),
      sortable: true,
      visible: true
    },
    {
      key: 'credential',
      label: i18n.t('Credential'),
      sortable: false,
      visible: false // hidden by default
    },
    {
      key: 'network',
      label: i18n.t('Network'),
      sortable: true,
      visible: true
    },
    {
      key: 'buttons',
      label: '',
      sortable: false,
      class: 'text-right',
      visible: true,
      locked: true
    }
  ])

  const visibleColumns = computed(() => {
    return columns.value.filter(column => column.visible)
  })

  const setColumns = (newColumns) => {
    columns.value = newColumns
  }

  return {
    columns,
    visibleColumns,
    setColumns,
    sortBy,
    sortDesc
  }
}

// @vue/component
export default {
  name: 'the-results',
  inheritAttrs: false,
  components,
  props,
  setup
}
</script>
