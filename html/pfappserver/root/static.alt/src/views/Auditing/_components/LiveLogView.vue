<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
      <b-row>
        <b-col sm="2">
          <template v-for="(children, scope) in scopes">
            <small :key="scope" class="ml-1">{{ children.label }}</small>
            <b-list-group :key="children" class="mt-1 mb-3">
              <template v-for="({ count, filter }, key) in children.values">
                <b-list-group-item :key="`${key}-${count}-${filter}`"
                  href="#" class="cursor-pointer"
                  :active="filter"
                  :variant="(filter) ? 'primary' : 'light'"
                  @click="toggleFilter(scope, key)"
                >
                  <template v-if="key">
                    {{ key }}
                  </template>
                  <template v-else>
                    <i>{{ $i18n.t('none') }}</i>
                  </template>
                  <b-badge class="float-right border text-secondary bg-light ml-1">{{ count }}</b-badge>
                </b-list-group-item>
              </template>
            </b-list-group>
          </template>
        </b-col>
        <b-col sm="10">
          <div editable="true" readonly="true" class="h-100 log">
            <div v-for="event in events" :key="event">
              {{ event }}
            </div>
          </div>
        </b-col>
      </b-row>
    </b-card-body>
  </b-card>
</template>

<script>
import i18n from '@/utils/locale'
import liveLogTabs from './LiveLogTabs'

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
    }
  },
  computed: {
    sessions () {
      return this.$store.getters[`$_live_logs/${this.id}/session`]
    },
    events () {
      return this.$store.getters[`$_live_logs/${this.id}/eventsFiltered`]
    },
    scopes () {
      return this.$store.getters[`$_live_logs/${this.id}/scopes`]
    }
  },
  methods: {
    toggleFilter (scope, key) {
      this.$store.dispatch(`$_live_logs/${this.id}/toggleFilter`, { scope, key }).then(() => {

      })
    }
  }
}
</script>

<style lang="scss">
.log {
  overflow-y: scroll;
  overflow-x: auto;
}
</style>
