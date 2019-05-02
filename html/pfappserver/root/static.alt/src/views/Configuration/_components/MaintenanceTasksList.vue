<template>
  <pf-config-list
    ref="pfConfigList"
    :config="config"
  >
    <template slot="pageHeader">
      <b-card-header>
        <h4 class="mb-3" v-t="'Maintenance Tasks'"></h4>
        <p class="mb-0" v-t="'Enabling or disabling a task as well as modifying its interval requires a restart of pfmon to be fully effective.'"></p>
      </b-card-header>
    </template>
    <template slot="buttonAdd">
      <pf-button-service service="pfmon" class="mr-1" restart start stop></pf-button-service>
    </template>
    <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No maintenance tasks found') }}</pf-empty-table>
    </template>
    <template slot="status" slot-scope="data">
      <pf-form-range-toggle
        v-model="data.status"
        :values="{ checked: 'enabled', unchecked: 'disabled' }"
        :icons="{ checked: 'check', unchecked: 'times' }"
        :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
        :disabled="isLoading"
        @input="toggleStatus(data, $event)"
        @click.stop.prevent
      >{{ (data.status === 'enabled') ? $t('Enabled') : $t('Disabled') }}</pf-form-range-toggle>
    </template>
    <template slot="interval" slot-scope="item">
      {{ item.interval.interval }}{{ item.interval.unit }}
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationMaintenanceTasksListConfig as config
} from '@/globals/configuration/pfConfigurationMaintenanceTasks'

export default {
  name: 'MaintenanceTasksList',
  components: {
    pfButtonDelete,
    pfButtonService,
    pfConfigList,
    pfEmptyTable,
    pfFormRangeToggle
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      config: config(this)
    }
  },
  methods: {
    toggleStatus (item, newStatus) {
      switch (newStatus) {
        case 'enabled':
          this.$store.dispatch(`${this.storeName}/enableMaintenanceTask`, item)
          break
        case 'disabled':
          this.$store.dispatch(`${this.storeName}/disableMaintenanceTask`, item)
          break
      }
    }
  }
}
</script>
