<template>
    <b-card no-body>
        <b-card-header>
            <h4 class="mb-0" v-t="'Network Devices'"></h4>
        </b-card-header>
        <b-tabs ref="tabs" v-model="tabIndex" card>
            <b-tab :title="$t('Switches')" @click="changeTab('switches')">
                <switches-list />
            </b-tab>
            <b-tab :title="$t('Switch Groups')" @click="changeTab('switch_groups')">
                <switch-group-list />
            </b-tab>
        </b-tabs>
    </b-card>
</template>

<script>
import SwitchesList from './SwitchesList'
import SwitchGroupsList from './SwitchGroupsList'

export default {
  name: 'NetworkDeviceTabs',
  components: {
    SwitchesList,
    SwitchGroupsList
  },
  props: {
    tab: {
      type: String,
      default: 'switches'
    }
  },
  computed: {
    tabIndex () {
      return ['switches', 'switch_groups'].indexOf(this.tab)
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
