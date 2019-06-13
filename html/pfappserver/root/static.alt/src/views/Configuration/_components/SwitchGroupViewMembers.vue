<template>
  <div>
    <b-card no-body class="mb-3">
      <b-card-header>
        <h4 class="mb-0" v-t="'Current Members'"></h4>
      </b-card-header>
      <div class="card-body">
        <b-table
          :items="members"
          :fields="fields"
          :sort-by="sortBy"
          :sort-desc="sortDesc"
          show-empty
          responsive
          fixed
          class="mb-0"
        >
          <template slot="empty">
            <pf-empty-table :isLoading="isLoading" :text="$t('Click the button below to add a new member.')">{{ $t('No switch group members found') }}</pf-empty-table>
          </template>
          <template slot="id" slot-scope="data">
            <a href="javascript:void(0)" @click.prevent="clickSwitch(data.item)">{{ data.value }}</a>
          </template>
          <template slot="buttons" slot-scope="data">
            <pf-button-delete v-if="id !== 'default'" size="sm" variant="outline-danger" class="mr-1" :disabled="isLoading" :confirm="$t('Delete Member?')" @on-delete="remove(data.item)" reverse/>
          </template>
        </b-table>
      </div>
    </b-card>
    <b-card no-body>
      <b-card-header>
        <h4 class="mb-0" v-t="'New Member'"></h4>
      </b-card-header>
      <b-row class="p-3">
        <b-col cols="3" class="pr-1">
          <pf-form-chosen
            v-model="memberId"
            :placeholder="$t('Type to search')"
            label="text"
            track-by="value"
            :searchable="true"
            :internalSearch="true"
            :preserveSearch="true"
            :clearOnSelect="true"
            :allowEmpty="false"
            :options="filteredSwitches"
            :disabled="isLoading"
          ></pf-form-chosen>
        </b-col>
        <b-col class="pl-1">
          <b-button variant="outline-primary" :disabled="!memberId || isLoading" @click="add()">{{ $t('Add new member') }}</b-button>
        </b-col>
      </b-row>
    </b-card>
  </div>
</template>

<script>
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormChosen from '@/components/pfFormChosen'
import i18n from '@/utils/locale'

export default {
  name: 'SwitchGroupViewMembers',
  components: {
    pfButtonDelete,
    pfEmptyTable,
    pfFormChosen
  },
  props: {
    id: {
      type: String,
      default: null,
      required: true
    },
    members: {
      type: Array,
      default: () => { return [] },
      required: true
    }
  },
  data () {
    return {
      fields: [
        {
          key: 'id',
          label: i18n.t('Identifier'),
          required: true,
          sortable: true,
          visible: true
        },
        {
          key: 'description',
          label: i18n.t('Description'),
          sortable: true,
          visible: true
        },
        {
          key: 'type',
          label: i18n.t('Type'),
          sortable: true,
          visible: true
        },
        {
          key: 'buttons',
          label: '',
          locked: true,
          class: 'text-right'
        }
      ],
      sortBy: 'id',
      sortDesc: false,
      memberId: null,
      switches: []
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_switches/isLoading'] || this.$store.getters['$_switch_groups/isLoading']
    },
    filteredSwitches () {
      return this.switches.map(switche => {
        return {
          text: `${switche.id} (${switche.description})`,
          value: switche.id,
          $isDisabled: this.members.map(member => member.id).includes(switche.id)
        }
      })
    }
  },
  methods: {
    add () {
      this.$store.dispatch('$_switches/updateSwitch', { quiet: true, id: this.memberId, group: this.id }).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Switch <code>{id}</code> added to group.', { id: this.memberId }) })
        this.memberId = null
        this.$store.dispatch('$_switch_groups/getSwitchGroupMembers', this.id).then(members => {
          this.members = members
        })
      })
    },
    remove (item) {
      this.$store.dispatch('$_switches/updateSwitch', { quiet: true, id: item.id, group: null }).then(response => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('Switch <code>{id}</code> removed from group.', { id: item.id }) })
        this.$store.dispatch('$_switch_groups/getSwitchGroupMembers', this.id).then(members => {
          this.members = members
        })
      })
    },
    clickSwitch (item) {
      this.$router.push({ name: 'switch', params: { id: item.id } })
    }
  },
  created () {
    this.$store.dispatch('$_switches/all').then(switches => {
      this.switches = switches
    })
  }
}
</script>
