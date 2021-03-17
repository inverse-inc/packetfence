<template>
  <div>
    <pf-config-list
      ref="pfConfigList"
      :config="config"
    >
      <template v-slot:pageHeader>
        <h4 class="mb-0 p-4">
          {{ $t('Active Directory Domains') }}
          <pf-button-help class="ml-1" url="PacketFence_Installation_Guide.html#_microsoft_active_directory_ad" />
        </h4>
      </template>
      <template v-slot:buttonAdd>
        <b-button variant="outline-primary" :to="{ name: 'newDomain' }">{{ $t('New Domain') }}</b-button>
      </template>
      <template v-slot:emptySearch="state">
          <pf-empty-table :isLoading="state.isLoading">{{ $t('No domains found') }}</pf-empty-table>
      </template>
      <template v-slot:cell(ntlm_cache)="item">
        <icon name="circle" :class="{ 'text-success': item.ntlm_cache === 'enabled', 'text-danger': item.ntlm_cache !== 'enabled' }"
          v-b-tooltip.hover.left.d300 :title="$t(item.ntlm_cache)"></icon>
      </template>
      <template v-slot:cell(joined)="item">
        <template v-if="item.id in joins">
          <icon v-if="joins[item.id].status === null" name="circle-notch" class="text-secondary" spin></icon>
          <icon v-else-if="joins[item.id].status === true" name="circle" class="text-success"
            v-b-tooltip.hover.left.d300 :title="$t('Test join success.')"></icon>
          <icon v-else-if="joins[item.id].status === false" name="circle" class="text-danger"
            v-b-tooltip.hover.left.d300 :title="$t('Test join failed.')"></icon>
          <span v-if="joins[item.id].message" v-t="joins[item.id].message" class="ml-1"></span>
        </template>
      </template>
      <template v-slot:cell(buttons)="item">
        <span class="float-right text-nowrap">
          <pf-button-delete size="sm" v-if="!item.not_deletable" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Domain?')" @on-delete="remove(item)" reverse/>
          <b-button size="sm" variant="outline-primary" class="mr-1" @click.stop.prevent="clone(item)">{{ $t('Clone') }}</b-button>
          <button-join size="sm" :id="item.id" />
        </span>
      </template>
    </pf-config-list>
  </div>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfButtonHelp from '@/components/pfButtonHelp'
import pfConfigList from '@/components/pfConfigList'
import pfEmptyTable from '@/components/pfEmptyTable'
import { ButtonJoin } from '@/views/Configuration/domains/_components/'
import { config } from '../_config/domain'

export default {
  name: 'domains-list',
  components: {
    pfButtonDelete,
    pfButtonHelp,
    pfConfigList,
    pfEmptyTable,
    ButtonJoin
  },
  props: {
    autoJoinDomain: { // from DomainView, through router
      type: Object,
      default: null
    }
  },
  data () {
    return {
      config: config(this)
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_domains/isLoading']
    },
    joins () {
      return this.$store.getters['$_domains/joins']
    }
  },
  methods: {
    clone (item) {
      this.$router.push({ name: 'cloneDomain', params: { id: item.id } })
    },
    remove (item) {
      this.$store.dispatch('$_domains/deleteDomain', item.id).then(() => {
        const { $refs: { pfConfigList: { refreshList = () => {} } = {} } = {} } = this
        refreshList() // soft reload
      })
    }
  }
}
</script>
