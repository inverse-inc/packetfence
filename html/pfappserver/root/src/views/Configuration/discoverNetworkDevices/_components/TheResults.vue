<template>
  <div>
    <div v-if="devices.length > 0" class="d-flex justify-content-end mb-3">
      <b-button
        variant="outline-danger"
        size="sm"
        :disabled="isLoading"
        @click="$emit('clear')"
      >{{ $t('Clear All') }}</b-button>
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
          <small v-if="item.credential.value" class="text-muted">
            ({{ item.credential.value }})
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
            v-if="switchIds.includes(item.ip)"
            size="sm"
            variant="outline-primary"
            class="mr-1"
            :disabled="isLoading"
            @click.stop="$emit('view-switch', item.ip)"
          >{{ $t('View Switch') }}</b-button>
          <template v-else>
            <b-dropdown
              v-if="getMatchingTypes(item.driver).length > 1"
              size="sm"
              variant="outline-success"
              class="mr-1"
              :disabled="isLoading"
              :text="$t('Create Switch')"
              right
            >
              <b-dropdown-item
                v-for="switchType in getMatchingTypes(item.driver)"
                :key="switchType"
                @click.stop="$emit('create-switch', { ...item, type: switchType })"
              >{{ switchType }}</b-dropdown-item>
            </b-dropdown>
            <b-button
              v-else
              size="sm"
              variant="outline-success"
              class="mr-1"
              :disabled="isLoading"
              @click.stop="$emit('create-switch', { ...item, type: getMatchingTypes(item.driver)[0] || '' })"
            >{{ $t('Create Switch') }}</b-button>
          </template>
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
import { computed, ref, toRefs } from '@vue/composition-api'
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
  switchIds: {
    type: Array,
    default: () => ([])
  },
  switchTypes: {
    type: Array,
    default: () => ([])
  },
  isLoading: {
    type: Boolean,
    default: false
  }
}

// Normalize string for comparison: lowercase and remove separators
const normalizeForMatch = (str) => {
  if (!str) return ''
  return str.toLowerCase().replace(/[_:-]/g, '')
}

// Find matching switch types for a driver
// e.g., driver "cisco_catalyst" should match "Cisco::Catalyst_2900", "Cisco::Catalyst_2950", etc.
const findMatchingTypes = (driver, switchTypes) => {
  if (!driver || !switchTypes.length) return []
  // Split driver into parts for flexible matching (e.g., "cisco_catalyst" -> ["cisco", "catalyst"])
  const driverParts = driver.toLowerCase().split(/[_:-]/).filter(Boolean)

  return switchTypes.filter(type => {
    const normalizedFullType = normalizeForMatch(type)
    // Check if all driver parts are present in the type
    return driverParts.every(part => normalizedFullType.includes(part))
  })
}

const setup = (props) => {
  const { switchTypes } = toRefs(props)
  const sortBy = ref('ip')
  const sortDesc = ref(false)

  // Get matching switch types for a device's driver
  const getMatchingTypes = (driver) => {
    return findMatchingTypes(driver, switchTypes.value || [])
  }

  const columns = ref([
    {
      key: 'network',
      label: i18n.t('Network'),
      sortable: true,
      visible: true,
      locked: true
    },
    {
      key: 'ip',
      label: i18n.t('IP Address'),
      sortable: true,
      class: 'text-nowrap',
      visible: true
    },
    {
      key: 'vendor',
      label: i18n.t('Vendor'),
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
      visible: true
    },
    {
      key: 'driver',
      label: i18n.t('Driver'),
      sortable: true,
      visible: false
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
    sortDesc,
    getMatchingTypes
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
