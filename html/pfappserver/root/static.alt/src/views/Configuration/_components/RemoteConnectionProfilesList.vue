<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
      :sortable="true"
      @sort="sort"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0">
            {{ $t('Remote Connection Profiles') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_remote_connection_profiles" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newRemoteConnectionProfile' }">{{ $t('New Remote Connection Profile') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No remote connection profiles found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Remote Connection Profile?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template v-slot:cell(status)="item">
        <pf-form-range-toggle v-if="item.not_deletable"
          v-model="item.status"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :icons="{ checked: 'lock', unchecked: 'lock' }"
          :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
          :right-labels="{ checked: $t('Enabled'), unchecked: $t('Disabled') }"
          disabled
        />
        <pf-form-range-toggle v-else
          v-model="item.status"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :icons="{ checked: 'check', unchecked: 'times' }"
          :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
          :right-labels="{ checked: $t('Enabled'), unchecked: $t('Disabled') }"
          :lazy="{ checked: enable(item), unchecked: disable(item) }"
          @click.stop.prevent
        />
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import { config } from '../_config/remoteConnectionProfile'

export default {
  name: 'remote-connection-profiles-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable,
    pfFormRangeToggle
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_remote_connection_profiles/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneRemoteConnectionProfile', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_remote_connection_profiles/deleteRemoteConnectionProfile', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    sort (items) {
      this.$store.dispatch('$_remote_connection_profiles/sortRemoteConnectionProfiles', items.map(item => item.id)).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Remote Connection Profiles resorted.') })
      })
    },
    enable (item) {
      return () => { // 'enabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_remote_connection_profiles/enableRemoteConnectionProfile', item).then(() => {
            const searchableStoreName = this.$refs.pfConfigList.searchableStoreName
            this.$store.dispatch(`${searchableStoreName}/updateItem`, { key: 'id', id: item.id, prop: 'status', data: 'enabled' }).then(() => {
              resolve('enabled')
            })
          }).catch(() => {
            reject() // reset
          })
        })
      }
    },
    disable (item) {
      return () => { // 'disabled'
        return new Promise((resolve, reject) => {
          this.$store.dispatch('$_remote_connection_profiles/disableRemoteConnectionProfile', item).then(() => {
            const searchableStoreName = this.$refs.pfConfigList.searchableStoreName
            this.$store.dispatch(`${searchableStoreName}/updateItem`, { key: 'id', id: item.id, prop: 'status', data: 'disabled' }).then(() => {
              resolve('disabled')
            })
          }).catch(() => {
            reject() // reset
          })
        })
      }
    }
  }
}
</script>
