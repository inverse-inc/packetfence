<template>
  <b-card no-body>
    <pf-progress :active="isLoading"></pf-progress>
    <b-card-header>
      <h4 class="mb-0" v-t="'Import Nodes'"></h4>
    </b-card-header>
    <div class="card-body">
      <b-tabs ref="tabs" v-model="tabIndex" card>
        <b-tab v-for="(file, index) in files" :key="file.name + file.lastModified" :title="file.name" no-body>
          <template slot="title">
            <b-button-close class="float-right ml-3" @click.stop.prevent="closeFile(index)" v-b-tooltip.hover.left.d300 :title="$t('Close File')"><icon name="times"></icon></b-button-close>
            {{ $t(file.name) }}
          </template>
          <pf-csv-parse @input="onImport" :ref="'parser-' + index" :file="file" :fields="fields" :storeName="storeName" no-init-bind-keys></pf-csv-parse>
        </b-tab>
        <template slot="tabs">
          <li role="presentation" class="nav-item" v-b-tooltip.hover.left.d300 :title="$t('Open CSV File')" style="cursor:pointer;">
            <div class="nav-link">
              <pf-form-upload @load="files = $event" :multiple="true" :cumulative="true" accept="text/*, .csv">
                <icon name="plus-circle" class="float-right mt-1 ml-3"></icon>
                {{ $t('Open CSV File') }}
              </pf-form-upload>
            </div>
          </li>
        </template>
        <div slot="empty" class="text-center text-muted">
          <b-container class="my-5">
            <b-row class="justify-content-md-center text-secondary">
                <b-col cols="12" md="auto">
                  <icon v-if="isLoading" name="sync" scale="2" spin></icon>
                  <b-media v-else>
                    <icon name="file" scale="2" slot="aside"></icon>
                    <h4>{{ $t('There are no open CSV files') }}</h4>
                    <p class="font-weight-light">{{ $t('Open a new CSV file using') }} <icon name="plus-circle"></icon> {{ $t('button') }}.</p>
                  </b-media>
                </b-col>
            </b-row>
          </b-container>
        </div>
      </b-tabs>
    </div>
  </b-card>
</template>

<script>
import pfCSVParse from '@/components/pfCSVParse'
import pfProgress from '@/components/pfProgress'
import pfFormUpload from '@/components/pfFormUpload'

import { required, minLength, maxLength, macAddress } from 'vuelidate/lib/validators'
// import { pfValidateMacAddressIsUnique as macAddressIsUnique } from '@/globals/pfValidators'

export default {
  name: 'NodesImport',
  components: {
    'pf-csv-parse': pfCSVParse,
    'pf-progress': pfProgress,
    'pf-form-upload': pfFormUpload
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  data () {
    return {
      files: [],
      tabIndex: 0,
      fields: [
        {
          value: 'mac',
          text: this.$i18n.t('MAC Address'),
          required: true,
          validators: { required, minLength: minLength(17), maxLength: maxLength(17), macAddress }
        },
        {
          value: 'bypass_role_id',
          text: this.$i18n.t('Bypass Role'),
          required: false
        },
        {
          value: 'bypass_vlan',
          text: this.$i18n.t('Bypass VLAN [?]'),
          required: false
        },
        {
          value: 'computername',
          text: this.$i18n.t('Computer Name'),
          required: false
        },
        {
          value: 'regdate',
          text: this.$i18n.t('Datetime Registered'),
          required: false
        },
        {
          value: 'unregdate',
          text: this.$i18n.t('Datetime Unregistered'),
          required: false
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          required: false
        },
        {
          value: 'pid',
          text: this.$i18n.t('Owner'),
          required: false
        },
        {
          value: 'category_id',
          text: this.$i18n.t('Role'),
          required: false
        },
        {
          value: 'voip',
          text: this.$i18n.t('VoIP'),
          required: false
        },
        {
          value: 'autoreg',
          text: this.$i18n.t('Auto Registration'),
          required: false
        },
        {
          value: 'bandwidth_balance',
          text: this.$i18n.t('Bandwidth Balance'),
          required: false
        }
      ]
    }
  },
  methods: {
    closeFile (index) {
      this.files.splice(index, 1)
    },
    onKeyDown (event) {
      // pass event to selected child component
      if (this.$refs['parser-' + this.tabIndex] && this.$refs['parser-' + this.tabIndex].length) {
        this.$refs['parser-' + this.tabIndex][0].onKeyDown(event)
      }
    },
    onImport (values) {
      values.forEach((value, index, values) => {
        value._tableValue._rowDisabled = true
      })
      this.$forceUpdate()
      console.log(['onImport', values])
    }
  },
  mounted () {
    if (!this.noInitBindKeys) {
      document.addEventListener('keydown', this.onKeyDown)
    }
  },
  beforeDestroy () {
    if (!this.noInitBindKeys) {
      document.removeEventListener('keydown', this.onKeyDown)
    }
  }
}
</script>
