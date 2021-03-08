<template>
  <pf-config-list
    ref="pfConfigList"
    :config="config"
  >
    <template v-slot:pageHeader>
      <b-card-header>
        <h4 class="mb-3" v-t="'Maintenance Tasks'"></h4>
        <p class="mb-0" v-t="'Enabling or disabling a task as well as modifying its interval requires a restart of pfcron to be fully effective.'"></p>
      </b-card-header>
    </template>
    <template v-slot:buttonAdd>
      <pf-button-service service="pfcron" class="mr-1" restart start stop :disabled="isLoading"></pf-button-service>
    </template>
    <template v-slot:emptySearch="state">
      <pf-empty-table :isLoading="state.isLoading">{{ $t('No maintenance tasks found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(status)="item">

      <pre>{{ {item} }}</pre>
      <base-input-range-promise v-model="item.status" />



      <pf-form-range-toggle
        v-model="item.status"
        :values="{ checked: 'enabled', unchecked: 'disabled' }"
        :icons="{ checked: 'check', unchecked: 'times' }"
        :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
        :rightLabels="{ checked: $t('Enabled'), unchecked: $t('Disabled') }"
        :lazy="{ checked: enable(item), unchecked: disable(item) }"
        @click.stop.prevent
      />
    </template>
    <template v-slot:cell(interval)="{ interval }">
      <template v-if="interval"><!-- TODO: Temporary workaround for issue #4902 -->
        {{ interval.interval }}{{ interval.unit }}
      </template>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonService from '@/components/pfButtonService'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import { config } from '../_config/maintenanceTask'
import {
  BaseInputRangePromise
} from '@/components/new/'

export default {
  name: 'maintenance-tasks-list',
  components: {
    pfButtonService,
    pfConfigList,
    pfEmptyTable,
    pfFormRangeToggle,
    BaseInputRangePromise
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_maintenance_tasks/isLoading']
    }
  },
  methods: {
    enable (item) {
      return () => { // 'enabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_maintenance_tasks/enableMaintenanceTask', item).then(() => {
            resolve('enabled')
          }).catch(() => {
            reject() // reset
          })
        })
      }
    },
    disable (item) {
      return () => { // 'disabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_maintenance_tasks/disableMaintenanceTask', item).then(() => {
            resolve('disabled')
          }).catch(() => {
            reject() // reset
          })
        })
      }
    }
  }
}
</script>
