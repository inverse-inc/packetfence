<template>
  <pf-config-list
    ref="pfConfigList"
    :config="config"
  >
    <template v-slot:buttonAdd>
      <b-dropdown :text="$t('New Switch')" class="mr-1" variant="outline-primary" no-flip>
        <b-dropdown-header class="text-secondary">{{ $t('To group') }}</b-dropdown-header>
          <b-dropdown-item v-for="(switchGroup, index) in switchGroups" :key="index"
            :to="{ name: 'newSwitch', params: { switchGroup: switchGroup.id } }">{{ switchGroup.id }}</b-dropdown-item>
      </b-dropdown>
      <b-button variant="outline-primary" :to="{ name: 'importSwitch' }">{{ $t('Import from CSV') }}</b-button>
    </template>
    <template v-slot:emptySearch="state">
      <pf-empty-table :is-loading="state.isLoading">{{ $t('No switches found') }}</pf-empty-table>
    </template>
    <template v-slot:cell(type)="item">
      <template v-if="switchTemplates.includes(item.type)">
        <b-link :to="{ name: 'switchTemplate', params: { id: item.type } }" v-b-tooltip.hover.top.d300 :title="$t('View Switch Template')">{{ item.type }}</b-link>
      </template>
      <template v-else>
        {{ item.type }}
      </template>
    </template>
    <template v-slot:cell(buttons)="item">
      <span class="float-right text-nowrap text-right">
        <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Switch?')" @on-delete="remove(item)" reverse/>
        <b-button size="sm" variant="outline-secondary" class="mr-1" @click.stop.prevent="invalidate(item)">{{ $t('Invalidate Cache') }}</b-button>
        <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
      </span>
    </template>
  </pf-config-list>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { config } from '../_config/switch'

export default {
  name: 'switches-list',
  components: {
    pfButtonDelete,
    pfConfigList,
    pfEmptyTable
  },
  data () {
    return {
      switchGroups: [], // all switches
      switchTemplates: [], // all switch templates
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_switches/isLoading']
    }
  },
  methods: {
    init () {
      this.$store.dispatch('$_switches/optionsBySwitchGroup').then(switchGroupOptions => {
        const { meta: { type: { allowed: switchGroups = [] } = {} } = {} } = switchGroupOptions
        switchGroups.map(switchGroup => {
          const { options: switchGroupMembers } = switchGroup
          switchGroupMembers.map(switchGroupMember => {
              const { is_template, value } = switchGroupMember
              if (is_template) {
                this.switchTemplates.push(value)
              }
          })
        })
      })
      this.$store.dispatch('$_switch_groups/all').then(switchGroups => {
        this.switchGroups = switchGroups.sort((a, b) => a.id.localeCompare(b.id))
      })
    },
    clone (item) {
      this.$router.push({ name: 'cloneSwitch', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_switches/deleteSwitch', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    },
    invalidate (item) {
      this.$store.dispatch('$_switches/invalidateSwitchCache', item.id).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Switch <code>{id}</code> cache invalidated', item) })
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      }).catch(() => {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Switch <code>{id}</code> cache could not be invalidated', item) })
      })
    }
  },
  mounted () {
    this.init()
  }
}
</script>
