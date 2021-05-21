<template>
    <b-card no-body>
        <b-card-header>
            <h4 class="mb-0" v-t="'Domains'"></h4>
        </b-card-header>
        <b-tabs ref="tabs" v-model="tabIndex" card>
            <b-tab :title="$t('Active Directory Domains')" @click="changeTab('domains')" no-body>
                <domains-search :autoJoinDomain="autoJoinDomain" />
            </b-tab>
            <b-tab :title="$t('Realms')" @click="changeTab('realms')" no-body>
                <realms-list />
            </b-tab>
        </b-tabs>
    </b-card>
</template>

<script>
import DomainsSearch from '../domains/_components/TheSearch'
import RealmsList from './RealmsList'

export default {
  name: 'domains-tabs',
  components: {
    DomainsSearch,
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
    tabIndex: {
      get () {
        return ['domains', 'realms'].indexOf(this.tab)
      },
      set () {
        // noop
      }
    }
  },
  methods: {
    changeTab (name) {
      this.$router.push({ name })
    }
  }
}
</script>
