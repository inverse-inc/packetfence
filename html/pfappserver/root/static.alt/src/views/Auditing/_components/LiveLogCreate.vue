<template>
  <b-card no-body>
    <b-card-header>
      <h4 v-t="'Live Logs'"></h4>
    </b-card-header>

    <live-log-tabs />

    <b-card-body>
      <b-form @submit.prevent="create()">
        <b-form-row align-v="center">
          <b-col sm="12">
            <pf-form-input :column-label="$t('Name')"
              v-model="form.name"
            />
            <pf-form-chosen :column-label="$t('Log Files')"
              v-model="form.files"
              :placeholder="$t('Choose file(s)')"
              :options="files"
              :multiple="true"
              label="name" track-by="value"
            />
            <pf-form-input :column-label="$t('Filter')"
              v-model="form.filter"
            />
            <pf-form-range-toggle :column-label="$t('Regular Expression')"
              v-model="form.filter_is_regexp"
              :values="{checked: true, unchecked: false}"
              :rightLabels="{checked: $t('Yes'), unchecked: $t('No')}"
            />
          </b-col>
        </b-form-row>
      </b-form>
    </b-card-body>
    <b-card-footer>
      <b-button variant="primary" :disabled="invalidForm" @click="create()">
        <icon name="circle-notch" spin v-show="isLoading"></icon> {{ $t('Start Session') }}
      </b-button>
    </b-card-footer>
  </b-card>
</template>

<script>
import pfFormChosen from '@/components/pfFormChosen'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import liveLogTabs from './LiveLogTabs'

export default {
  name: 'live-log-create',
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
    }
  },
  data () {
    return {
      form: {
        name: this.$i18n.t('New Session'),
        files: [],
        filter: null,
        filter_is_regexp: false
      },
      files: [
        '/usr/local/pf/logs/packetfence.log',
        '/usr/local/pf/logs/http.portal.access'
      ].map(file => {
        let split = file.split('/')
        return { name: split[split.length - 1], value: file }
      })
    }
  },
  methods: {
    create () {
      this.$store.dispatch(`${this.storeName}/createSession`, this.form).then(response => {
        // noop
      })
    }
  }
}
</script>
