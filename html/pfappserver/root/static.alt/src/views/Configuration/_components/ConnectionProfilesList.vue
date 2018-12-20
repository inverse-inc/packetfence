<template>
  <b-card no-body>
    <pf-config-list
      :config="config"
      :isLoading="isLoading"
    >
      <template slot="pageHeader">
        <b-card-header><h4 class="mb-0" v-t="'Connection Profiles'"></h4></b-card-header>
      </template>
      <template slot="buttonAdd">
        <b-button variant="outline-primary" :to="{ name: 'newConnectionProfile' }">{{ $t('Add Connection Profile') }}</b-button>
      </template>
      <template slot="emptySearch">
        <pf-empty-table :isLoading="isLoading">{{ $t('No connection profiles found') }}</pf-empty-table>
      </template>
      <template slot="buttons" slot-scope="item">
        <span class="float-right text-nowrap">
          <b-button size="sm" variant="outline-primary" class="mr-1" :to="{ name: 'TODO' }">{{ $t('Preview') }}</b-button>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <pf-button-delete  v-if="!item.not_deletable" size="sm" variant="outline-danger" :disabled="isLoading" :confirm="$t('Delete Connection Profile?')" @on-delete="remove(item)" reverse/>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import {
  pfConfigurationConnectionProfilesListColumns as columns,
  pfConfigurationConnectionProfilesListFields as fields
} from '@/globals/pfConfigurationConnectionProfiles'

export default {
  name: 'ConnectionProfilesList',
  components: {
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: {
        columns: columns,
        fields: fields,
        rowClickRoute (item, index) {
          return { name: 'connection_profile', params: { id: item.id } }
        },
        searchPlaceholder: this.$i18n.t('Search by identifier or description'),
        searchableOptions: {
          searchApiEndpoint: 'config/connection_profiles',
          defaultSortKeys: ['id'],
          defaultSearchCondition: {
            op: 'and',
            values: [{
              op: 'or',
              values: [
                { field: 'id', op: 'contains', value: null },
                { field: 'description', op: 'contains', value: null }
              ]
            }]
          },
          defaultRoute: { name: 'configuration/connection_profiles' }
        },
        searchableQuickCondition: (quickCondition) => {
          return {
            op: 'and',
            values: [
              {
                op: 'or',
                values: [
                  { field: 'id', op: 'contains', value: quickCondition },
                  { field: 'description', op: 'contains', value: quickCondition }
                ]
              }
            ]
          }
        }
      }
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
    }
  }
}
</script>
