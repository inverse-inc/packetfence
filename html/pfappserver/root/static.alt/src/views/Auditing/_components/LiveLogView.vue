<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
      <b-row>
        <b-col sm="3">
          <div class="scopes">
            <small :key="scope" class="ml-1">{{ $i18n.t('Session Options') }}</small>
            <b-list-group :key="children" class="mt-1 mb-3">
              <b-list-group-item variant="light">
                <small :key="scope" class="ml-1">{{ $i18n.t('Log Files') }}</small>
                <pf-form-chosen
                  v-model="session.files"
                  :disabled="isRunning"
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
                  :disabled="isRunning"
                  class="mt-1 mb-3"
                  placeholder="none"
                />

                <small :key="scope" class="ml-1">{{ $i18n.t('Regular Expression') }}</small>
                <pf-form-range-toggle
                  v-model="session.filter_is_regexp"
                  :disabled="isRunning"
                  :values="{checked: true, unchecked: false}"
                  :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
                  class="mt-1 mb-3"
                />

                <b-button v-if="isRunning"
                  :disabled="isStopping"
                  variant="danger" class="float-right mb-1" @click="stopSession()"
                >
                  <icon v-if="isStopping" name="circle-notch" class="mr-2" spin></icon>
                  <icon v-else name="stop" class="mr-2"></icon>
                  {{ $i18n.t('Stop Session') }}
                </b-button>
                <b-button v-else
                  :disabled="isStarting"
                  variant="success" class="float-right mb-1" @click="startSession()"
                >
                  <icon v-if="isStarting" name="circle-notch" class="mr-2" spin></icon>
                  <icon v-else name="play" class="mr-2"></icon>
                  {{ $i18n.t('Reset Session') }}
                </b-button>
              </b-list-group-item>
            </b-list-group>

            <small :key="scope" class="ml-1">{{ $i18n.t('Buffer Size') }}</small>
            <pf-form-chosen
              v-model="size"
              :options="sizes"
              :placeholder="$t('Choose max buffer size')"
              :allow-empty="false"
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
                      v-b-tooltip.hover.top.d300
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
          </div>
        </b-col>
        <b-col sm="9">
          <div editable="true" readonly="true" class="log scroll-reverse">
            <div class="scroll-reverse-only-child">
              <div v-for="event in events" :key="event">
                {{ event }}
              </div>
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
      ],
      isStarting: false
    }
  },
  computed: {
    session: {
      get () {
        return this.$store.getters[`$_live_logs/${this.id}/session`]
      },
      set (newSession) {
        this.$store.dispatch(`$_live_logs/${this.id}/setSession`, newSession)
      }
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
    },
    isLoading () {
      return this.$store.getters[`$_live_logs/${this.id}/isLoading`]
    },
    isStopping () {
      return this.$store.getters[`$_live_logs/${this.id}/isStopping`]
    },
    isRunning () {
      return this.$store.getters[`$_live_logs/${this.id}/isRunning`]
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`$_live_logs/optionsSession`, this.form).then(response => {
        const { meta: { files: { item: { allowed = [] } = {} } = {} } = {} } = response
        if (allowed) {
          this.files = allowed.map(item => {
            return { name: item.text, value: item.value }
          })
        }
      })
    },
    toggleFilter (scope, key) {
      this.$store.dispatch(`$_live_logs/${this.id}/toggleFilter`, { scope, key }).then(() => {
        // noop
      })
    },
    stopSession () {
      this.$store.dispatch(`$_live_logs/${this.id}/stopSession`).then(() => {
        // noop
      })
    },
    startSession () {
      this.isStarting = true
      const { session: { session_id, ...form } = {} } = this
      this.$store.dispatch(`$_live_logs/createSession`, form).then(response => {
        const { session_id } = response
        if (session_id) {
          this.$store.dispatch(`$_live_logs/${session_id}/setSize`, this.size)
          this.$nextTick(() => {
            this.$store.dispatch('$_live_logs/destroySession', this.id)
          })
          this.$router.push({ name: 'live_log', params: { id: session_id } })
        }
        this.isStarting = false
      }).catch(() => {
        this.isStarting = false
      })
    }
  },
  mounted () {
    this.init()
  }
}
</script>

<style lang="scss">
.log, .scopes {
  height: 75vh;
  overflow-y: scroll;
  overflow-x: auto;
}
.log {
  display: flex;
  align-items: flex-end;
}

/*
 reverse content, pin vertical scrollbar to the bottom,
   reverses content only on immediate children
*/
.scroll-reverse {
  flex-direction: column-reverse;
}

/*
  placeholder, only immediate children are reversed
*/
.scroll-reverse-only-child {}
</style>
