<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
      <b-row>
        <b-col sm="3">
          <div class="scopes pr-3">
            <small :key="scope" class="ml-1">{{ $i18n.t('Session Options') }}</small>
            <b-list-group :key="children" class="mt-1 mb-3">
              <b-list-group-item variant="light">
                <small :key="scope" class="ml-1">{{ $i18n.t('Log Files') }}</small>
                <pf-form-chosen v-if="session && 'files' in session"
                  v-model="session.files"
                  :disabled="isRunning"
                  :placeholder="$t('Choose log file(s)')"
                  :options="files"
                  :multiple="true"
                  :allow-empty="false"
                  :close-on-select="false"
                  :state="state('files')"
                  :invalid-feedback="invalidFeedback('files')"
                  class="mb-3"
                  label="name" track-by="value"
                />

                <small :key="scope" class="ml-1">{{ $i18n.t('Filter') }}</small>
                <pf-form-input v-if="session && 'filter' in session"
                  v-model="session.filter"
                  :disabled="isRunning"
                  class="mt-1 mb-3"
                  placeholder="none"
                />

                <small :key="scope" class="ml-1">{{ $i18n.t('Regular Expression') }}</small>
                <pf-form-range-toggle v-if="session && 'filter_is_regexp' in session"
                  v-model="session.filter_is_regexp"
                  :disabled="isRunning"
                  :values="{checked: true, unchecked: false}"
                  :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
                  class="mt-1 mb-3"
                />

                <b-button-group class="mt-3 btn-block">

                  <b-button v-if="isRunning && !isPaused"
                    variant="primary" class="mb-1" @click="pauseSession()"
                  >
                    <icon name="pause" class="mr-2"></icon>
                    {{ $i18n.t('Pause') }}
                  </b-button>
                  <b-button v-if="isRunning && isPaused"
                    variant="primary" class="mb-1" @click="unpauseSession()"
                  >
                    <icon name="play" class="mr-2"></icon>
                    {{ $i18n.t('Unpause') }}
                  </b-button>
                  <b-button v-if="isRunning"
                    :disabled="isStopping"
                    variant="danger" class="float-right mb-1" @click="stopSession()"
                  >
                    <icon v-if="isStopping" name="circle-notch" class="mr-2" spin></icon>
                    <icon v-else name="stop" class="mr-2"></icon>
                    {{ $i18n.t('Stop') }}
                  </b-button>
                  <b-button v-if="!isRunning"
                    :disabled="isStarting || invalidForm"
                    variant="success" class="float-right mb-1" @click="startSession()"
                  >
                    <icon v-if="isStarting" name="circle-notch" class="mr-2" spin></icon>
                    <icon v-else name="play" class="mr-2"></icon>
                    {{ $i18n.t('Reset') }}
                  </b-button>
                </b-button-group>
              </b-list-group-item>
            </b-list-group>

            <b-button-group class="mb-3 btn-block" :disabled="!events || !events.length">
              <b-button @click="copyEvents()" variant="outline-primary">{{ $t('Copy Log') }}</b-button>
              <b-button @click="saveEvents()" variant="outline-primary">{{ $t('Save Log') }}</b-button>
              <b-button @click="clearEvents()" variant="outline-danger">{{ $t('Clear Log') }}</b-button>
            </b-button-group>

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
        <b-col sm="9" class="pl-0">

          <div editable="true" readonly="true" class="log scroll-reverse">
            <div class="scroll-reverse-only-child">
              <div class="text-raw" v-if="events" v-html="events.map(event => event.data.raw).join('<br/>')" />
            <!--
              <div v-for="event in events" :key="event">
                <div class="line text-raw">
                  {{ event.data.raw }}
                </div>
              </div>
            -->
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

import { validationMixin } from 'vuelidate'
import {
  required
} from 'vuelidate/lib/validators'

export default {
  name: 'live-log-view',
  components: {
    liveLogTabs,
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle
  },
  mixins: [
    validationMixin
  ],
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
    },
    isPaused () {
      return this.$store.getters[`$_live_logs/${this.id}/isPaused`]
    },
    invalidForm () {
      const { $v: { $invalid = false } = {} } = this
      return $invalid
    },
    invalidFeedback () {
      return (key) => {
        const { $v: { session: { [key]: { $params } = {} } = {} } = {} } = this
        let feedback = []
        for (let param in $params) {
          const { $v: { session: { [key]: { [param]: valid = true } = {} } = {} } = {} } = this
          if (!valid) {
            feedback.push(param)
          }
        }
        return feedback.join(' ')
      }
    },
    state () {
      return (key) => {
        const { $v: { session: { [key]: { $invalid = false } = {} } = {} } = {} } = this
        return ($invalid) ? false : null
      }
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
    },
    pauseSession () {
      this.$store.dispatch(`$_live_logs/${this.id}/pauseSession`).then(() => {
        // noop
      })
    },
    unpauseSession () {
      this.$store.dispatch(`$_live_logs/${this.id}/unpauseSession`).then(() => {
        // noop
      })
    },
    clearEvents () {
      this.$store.dispatch(`$_live_logs/${this.id}/clearEvents`).then(response => {
        this.$store.dispatch('notification/info', { message: i18n.t('Cleared logs.') })
      })
    },
    copyEvents () {
      try {
        navigator.clipboard.writeText(this.events.map(event => event.data.raw).join('\n')).then(() => {
          this.$store.dispatch('notification/info', { message: i18n.t('Logs copied to clipboard.') })
        }).catch(() => {
          this.$store.dispatch('notification/danger', { message: i18n.t('Could not copy logs to clipboard.') })
        })
      } catch (e) {
        this.$store.dispatch('notification/danger', { message: i18n.t('Clipboard not supported.') })
      }
    },
    saveEvents () {
      // window.open(encodeURI(`data:text/csv;charset=utf-8,${csvContentArray.join('\r\n')}`)) // doesn't allow naming
      let blob = new Blob([this.events.map(event => event.data.raw).join('\r\n')], { type: 'text/plain' })
      let filename = this.session.name + ((this.session.name.slice(-4) === '.log') ? '' : '.log')
      if (window.navigator.msSaveOrOpenBlob) {
        window.navigator.msSaveBlob(blob, filename)
      } else {
        var elem = window.document.createElement('a')
        elem.href = window.URL.createObjectURL(blob)
        elem.download = filename
        document.body.appendChild(elem)
        elem.click()
        document.body.removeChild(elem)
      }
    }
  },
  mounted () {
    this.init()
  },
  validations () {
    return {
      session: {
        files: {
          [this.$i18n.t('Log file(s) required.')]: required
        }
      }
    }
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
