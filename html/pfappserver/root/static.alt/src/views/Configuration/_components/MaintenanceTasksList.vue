<template>
  <pf-config-list
    :config="config"
  >
    <template slot="pageHeader">
      <h4 v-t="'Maintenance Tasks'"></h4>
      <p v-t="'Enabling or disabling a task as well as modifying its interval requires a restart of pfmon to be fully effective.'"></p>
    </template>
    <template slot="buttonAdd">
      <b-button v-if="pfmonRunning"
        :disabled="pfmonWaiting"
        variant="outline-success" class="mr-1"
        @click.stop.prevent="restartPfmon()"
      >
        <icon name="circle-notch" spin class="mr-1" v-if="pfmonWaiting"></icon>
        <icon name="circle" v-else class="text-success mr-1" v-b-tooltip.hover.left.d300 :title="$t('{service} is running', { service: 'pfmon' })"></icon>
        {{ $t('Restart {service}', { service: 'pfmon' }) }}
      </b-button>
      <b-button v-else
        :disabled="pfmonWaiting"
        variant="outline-danger" class="mr-1"
        @click.stop.prevent="startPfmon()"
      >
        <icon name="circle-notch" spin class="mr-1" v-if="pfmonWaiting"></icon>
        <icon name="circle" v-else class="text-danger mr-1" v-b-tooltip.hover.left.d300 :title="$t('{service} is stopped', { service: 'pfmon' })"></icon>
        {{ $t('Start {service}', { service: 'pfmon' }) }}
      </b-button>
    </template>
    <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No maintenance tasks found') }}</pf-empty-table>
    </template>
    <template slot="status" slot-scope="data">
      <icon name="circle" :class="{ 'text-success': data.status === 'enabled', 'text-danger': data.status === 'disabled' }"
        v-b-tooltip.hover.left.d300 :title="$t(data.status)"></icon>
    </template>
    <template slot="interval" slot-scope="item">
      {{ item.interval.interval }}{{ item.interval.unit }}
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationMaintenanceTasksListConfig as config
} from '@/globals/configuration/pfConfigurationMaintenanceTasks'

export default {
  name: 'MaintenanceTasksList',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this),
      pfmon: {}
    }
  },
  computed: {
    pfmonWaiting () {
      const { status } = this.pfmon
      return [undefined, 'loading', 'starting', 'restarting'].includes(status)
    },
    pfmonRunning () {
      const { alive } = this.pfmon
      return alive || false
    }
  },
  methods: {
    restartPfmon () {
      this.$store.dispatch('$_services/restartService', 'pfmon').then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Successfully restarted {service}', { service: 'pfmon' }) })
      })
    },
    startPfmon () {
      this.$store.dispatch('$_services/startService', 'pfmon').then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Successfully started {service}', { service: 'pfmon' }) })
      })
    }
  },
  created () {
    this.$store.dispatch('$_services/getService', 'pfmon').then(response => {
      this.pfmon = response
    })
  }
}
</script>
