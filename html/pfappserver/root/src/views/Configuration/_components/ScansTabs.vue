<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Scans'"></h4>
    </b-card-header>
    <b-tabs ref="tabs" v-model="tabIndex" card lazy>
      <b-tab :title="$t('Scan Engines')" @click="changeTab('scan_engines')">
        <scan-engines-search />
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import ScanEnginesSearch from '../scanEngines/_components/TheSearch'

export default {
  name: 'scan-tabs',
  components: {
    ScanEnginesSearch
  },
  props: {
    tab: {
      type: String,
      default: 'scan_engines'
    }
  },
  computed: {
    tabIndex: {
      get () {
        return [
          'scan_engines'
        ].indexOf(this.tab)
      },
      set () {
        // noop
      }
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push(`./${name}`)
    }
  }
}
</script>
