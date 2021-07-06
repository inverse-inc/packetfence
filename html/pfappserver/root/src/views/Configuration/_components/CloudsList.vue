<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <h4 class="mb-0" v-t="'Cloud Service'"></h4>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-dropdown :text="$t('New Cloud')" variant="outline-primary">
          <b-dropdown-item :to="{ name: 'newCloud', params: { cloudType: 'Intune' } }">Microsoft Intune</b-dropdown-item>
        </b-dropdown>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :is-loading="state.isLoading">{{ $t('No clouds found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Cloud?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/cloud'

export default {
  name: 'clouds-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_clouds/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneCloud', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_clouds/deleteCloud', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
