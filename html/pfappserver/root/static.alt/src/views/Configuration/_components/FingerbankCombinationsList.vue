<template>
  <b-card no-body>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <b-card-header>
          <b-row class="align-items-center px-0" no-gutters>
            <b-col cols="auto" class="mr-auto">
              <h4 class="d-inline mb-0" v-t="'Combinations'"></h4>
            </b-col>
          </b-row>
        </b-card-header>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newFingerbankCombination' }">{{ $t('New Combination') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
        <pf-empty-table :isLoading="state.isLoading">{{ $t('No local combinations found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Combination?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
        </span>
      </template>
      <template v-slot:cell(score)="item">
        <pf-fingerbank-score :score="item.score"></pf-fingerbank-score>
      </template>
    </pf-config-list>
  </b-card>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFingerbankScore from '@/components/pfFingerbankScore'
import { config } from '../_config/fingerbank/combination'

export default {
  name: 'fingerbank-combinations-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable,
    pfFingerbankScore
  },
  data () {
    return {
      data: [],
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_fingerbank/isLoading']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneFingerbankCombination', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_fingerbank/deleteCombination', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  },
  created () {
    this.$store.dispatch('$_fingerbank/combinations').then(data => {
      this.data = data
    })
  }
}
</script>
