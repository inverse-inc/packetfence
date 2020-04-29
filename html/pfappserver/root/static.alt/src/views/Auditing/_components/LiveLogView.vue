<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
      <b-row>
        <b-col sm="2">

              <pre>{{ JSON.stringify(scopes, null, 2) }}</pre>


        </b-col>
        <b-col sm="10">
          <div editable="true" readonly="true" class="log">
            {{ JSON.stringify(events, null, 2) }}
          </div>
        </b-col>
      </b-row>
    </b-card-body>
  </b-card>
</template>

<script>
import i18n from '@/utils/locale'
import liveLogTabs from './LiveLogTabs'

const scopes = {
  hostname: {
    label: i18n.t('Hostname')
  },
  log_level: {
    label: i18n.t('Log Level')
  },
  process: {
    label: i18n.t('Process Name')
  },
  syslog_name: {
    label: i18n.t('Syslog Name')
  }
}

export default {
  name: 'live-log-view',
  components: {
    liveLogTabs
  },
  props: {
    storeName: {
      type: String,
      default: null
    },
    id: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      scopeFilters: {}
    }
  },
  computed: {
    sessions () {
      return this.$store.getters[`$_live_logs/${this.id}/session`]
    },
    events () {
      return this.$store.getters[`$_live_logs/${this.id}/events`]
    },
    scopes () {
      return this.$store.getters[`$_live_logs/${this.id}/scopes`]
    }
  },
  methods: {
  }
}
</script>

<style lang="scss">
.log {
  max-heigth: 100%;
  overflow-y: scroll;
}
</style>
