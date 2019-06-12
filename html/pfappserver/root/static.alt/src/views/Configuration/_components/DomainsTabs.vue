<template>
    <b-card no-body>
        <b-card-header>
            <h4 class="mb-0" v-t="'Domains'"></h4>
        </b-card-header>
        <b-tabs ref="tabs" v-model="tabIndex" card>
            <b-tab :title="$t('Active Directory Domains')" @click="changeTab('domains')" no-body>
                <domains-list storeName="$_domains" :autoJoinDomain="autoJoinDomain" />
            </b-tab>
            <b-tab :title="$t('Realms')" @click="changeTab('realms')" no-body>
                <realms-list storeName="$_realms" />
            </b-tab>
        </b-tabs>
    </b-card>
</template>

<script>
import DomainsList from './DomainsList'
import RealmsList from './RealmsList'

export default {
  name: 'domains-tabs',
  components: {
    DomainsList,
    RealmsList
  },
  props: {
    tab: {
      type: String,
      default: 'domains'
    },
    autoJoinDomain: { // from DomainView, through router
      type: Object,
      default: null
    }
  },
  computed: {
    tabIndex () {
      return ['domains', 'realms'].indexOf(this.tab)
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
