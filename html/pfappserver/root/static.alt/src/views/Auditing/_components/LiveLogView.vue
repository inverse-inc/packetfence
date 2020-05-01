<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
      <b-row>
        <b-col sm="3">
          <small :key="scope" class="ml-1">{{ $i18n.t('Session Options') }}</small>
          <b-list-group :key="children" class="mt-1 mb-3">
            <b-list-group-item variant="light">
              <small :key="scope" class="ml-1">{{ $i18n.t('Log Files') }}</small>
              <pf-form-chosen
                v-model="session.files"
                :placeholder="$t('Choose log file(s)')"
                :options="files"
                :multiple="true"
                :allow-empty="false"
                :close-on-select="false"
                class="mb-3"
                label="name" track-by="value"
              />

              <small :key="scope" class="ml-1">{{ $i18n.t('Filter') }}</small>
              <pf-form-input
                v-model="session.filter"
                class="mt-1 mb-3"
                placeholder="none"
              />

              <small :key="scope" class="ml-1">{{ $i18n.t('Regular Expression') }}</small>
              <pf-form-range-toggle
                v-model="session.filter_is_regexp"
                :values="{checked: true, unchecked: false}"
                :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
                class="mt-1"
              />
            </b-list-group-item>
          </b-list-group>

          <small :key="scope" class="ml-1">{{ $i18n.t('Buffer Size') }}</small>
          <pf-form-chosen
            v-model="size"
            :options="sizes"
            :placeholder="$t('Choose max buffer size')"
            label="name" track-by="value"
            class="mb-3"
          />
          <template v-if="lines > 0">
            <template v-for="(children, scope) in scopes">
              <small :key="scope" class="ml-1">{{ children.label }}</small>
              <b-list-group :key="children" class="mt-1 mb-3">
                <template v-for="({ count, filter }, key) in children.values">
                  <b-list-group-item :key="`${key}-${count}-${filter}`"
                    href="#" class="cursor-pointer"
                    :active="filter"
                    :variant="(filter) ? 'primary' : 'light'"
                    @click="toggleFilter(scope, key)"
                    :title="(filter) ? $i18n.t('Click to disable filter') : $i18n.t('Click to enable filter')"
                    v-b-tooltip.hover.right.d300
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
          </template>
        </b-col>
        <b-col sm="9">
          <div editable="true" readonly="true" class="log">
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
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'

export default {
  name: 'live-log-view',
  components: {
    liveLogTabs,
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle
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
      files: [],
      sizes: [
        { name: '100', value: 100 },
        { name: '250', value: 250 },
        { name: '500', value: 500 },
        { name: '1000', value: 1000 },
        { name: '2500', value: 2500 },
        { name: '5000', value: 5000 }
      ]
    }
  },
  computed: {
    session () {
      return this.$store.getters[`$_live_logs/${this.id}/session`]
    },
    events () {
      return this.$store.getters[`$_live_logs/${this.id}/eventsFiltered`]
    },
    scopes () {
      return this.$store.getters[`$_live_logs/${this.id}/scopes`]
    },
    lines () {
      return this.$store.getters[`$_live_logs/${this.id}/lines`]
    },
    size: {
      get () {
        return this.$store.getters[`$_live_logs/${this.id}/size`]
      },
      set (newSize) {
        this.$store.dispatch(`$_live_logs/${this.id}/setSize`, newSize)
      }
    }
  },
  methods: {
    init () {
console.log('init')
      this.$store.dispatch(`$_live_logs/optionsSession`, this.form).then(response => {
        const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
        if (allowed) {
console.log({allowed})
          this.files = allowed.map(item => {
            return { name: item.text, value: item.value }
          })
        }
      })
    },
    toggleFilter (scope, key) {
      this.$store.dispatch(`$_live_logs/${this.id}/toggleFilter`, { scope, key }).then(() => {

      })
    }
  },
  mounted () {
    this.init()
  }
}
</script>

<style lang="scss">
.log {
  height: 100vh;
  overflow-y: scroll;
  overflow-x: auto;
}
</style>
