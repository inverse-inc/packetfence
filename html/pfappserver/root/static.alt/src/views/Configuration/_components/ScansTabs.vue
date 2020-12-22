<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Scans'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card>
      <b-tab :title="$t('Scan Engines')" @click="changeTab('scan_engines')">
        <scan-engines-list />
      </b-tab>
      <b-tab :title="$t('WMI Rules')" @click="changeTab('wmi_rules')">
        <wmi-rules-list />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import FormStore from '@/store/base/form'
import ScanEnginesList from './ScanEnginesList'
import WmiRulesList from './WmiRulesList'

export default {
  name: 'scan-tabs',
  components: {
    ScanEnginesList,
    WmiRulesList
  },
  props: {
    tab: {
      type: String,
      default: 'scan_engines'
    }
  },
  computed: {
    tabIndex () {
      return [
        'scan_engines',
        'wmi_rules'
      ].indexOf(this.tab)
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push(`./${name}`)
    }
  },
  beforeMount () {
    if (!this.$store.state.formScanEngine) { // Register store module only once
      this.$store.registerModule('formScanEngine', FormStore)
    }
    if (!this.$store.state.formWmiRule) { // Register store module only once
      this.$store.registerModule('formWmiRule', FormStore)
    }
  }
}
</script>
