<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Connection Profiles'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newConnectionProfile' }">{{ $t('Add Connection Profile') }}</b-button>
      </template>
      <template slot="emptySearch" slot-scope="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No connection profiles found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Connection Profile?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" :to="{ name: 'TODO' }">{{ $t('Preview') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template slot="status" slot-scope="data">
        <pf-form-range-toggle v-if="data.not_deletable"
          v-model="data.status"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :icons="{ checked: 'lock', unchecked: 'lock' }"
          :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
          disabled
        >{{ (data.status === 'enabled') ? $t('Enabled') : $t('Disabled') }}</pf-form-range-toggle>
        <pf-form-range-toggle v-else
          v-model="data.status"
          :values="{ checked: 'enabled', unchecked: 'disabled' }"
          :icons="{ checked: 'check', unchecked: 'times' }"
          :colors="{ checked: 'var(--success)', unchecked: 'var(--danger)' }"
          :disabled="isLoading"
          @input="toggleStatus(data, $event)"
          @click.stop.prevent
        >{{ (data.status === 'enabled') ? $t('Enabled') : $t('Disabled') }}</pf-form-range-toggle>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import {
  pfConfigurationConnectionProfileListConfig as config
} from '@/globals/configuration/pfConfigurationConnectionProfiles'

export default {
  name: 'ConnectionProfilesList',
  components: {
    pfButtonDelete,
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
      return this.$store.getters[`$_connection_profiles/isLoading`]
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneConnectionProfile', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_connection_profiles/deleteConnectionProfile', item.id).then(response => {
        this.$router.go() // reload
      })
    },
    toggleStatus (item, newStatus) {
      switch (newStatus) {
        case 'enabled':
          this.$store.dispatch('$_connection_profiles/enableConnectionProfile', item).then(response => {
            this.$refs.pfConfigList.submitSearch() // redo search
          })
          break
        case 'disabled':
          this.$store.dispatch('$_connection_profiles/disableConnectionProfile', item).then(response => {
            this.$refs.pfConfigList.submitSearch() // redo search
          })
          break
      }
    }
  }
}
</script>
