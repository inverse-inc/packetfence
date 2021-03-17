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
            {{ $t('Connection Profiles') }}
            <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_connection_profiles" />
          </h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newConnectionProfile' }">{{ $t('New Connection Profile') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No connection profiles found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Connection Profile?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-secondary" class="mr-1" @click.stop.prevent="preview(item)">{{ $t('Preview') }} <icon class="ml-1" name="external-link-alt"></icon></b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template v-slot:cell(status)="item">
         <toggle-status :value="item.status" :disabled="item.not_deletable || isLoading"
          :item="item" :searchable-store-name="$refs.pfConfigList.searchableStoreName" /> 
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/connectionProfile'
import { ToggleStatus } from '@/views/Configuration/connectionProfiles/_components/'

export default {
  name: 'connection-profiles-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable,
    ToggleStatus
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_connection_profiles/isLoading']
    }
  },
  methods: {
    preview (item) {
      window.open(`/portal_preview/captive-portal?PORTAL=${item.id}`, '_blank')
    },
    clone (item) {
      this.$router.push({ name: 'cloneConnectionProfile', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_connection_profiles/deleteConnectionProfile', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    sort (items) {
      this.$store.dispatch('$_connection_profiles/sortConnectionProfiles', items.map(item => item.id)).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Connection profiles resorted.') })
      })
    }
  }
}
</script>
