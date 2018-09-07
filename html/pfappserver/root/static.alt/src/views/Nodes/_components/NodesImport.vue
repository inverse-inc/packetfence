<template>
  <b-card no-body>
    <b-progress height="2px" :value="progressValue" :max="progressTotal" v-show="progressValue > 0 && progressValue < progressTotal"></b-progress>
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
import convert from '@/utils/convert'

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
          text: '⚠ ' + this.$i18n.t('MAC Address'),
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
      ],
      progressTotal: 0,
      progressValue: 0,
      promises: Array
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
      // track progress
      this.progressValue = 1
      this.progressTotal = values.length + 1
      // track promises
      this.promises = []
      values.forEach((value, index, values) => {
        this.$store.dispatch('$_nodes/exists', value.mac).then(results => {
          // node does not exist
          this.updateNode(value).then(results => {
            console.log(value)
            value._tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            if (results.message) {
              value._tableValue._rowMessage = this.$i18n.t(results.message)
            }
          }).catch((err) => {
            throw err
          })
        }).catch(() => {
          // node already exists
          this.createNode(value).then(results => {
            value._tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            if (results.message) {
              value._tableValue._rowMessage = this.$i18n.t(results.message)
            }
          }).catch((err) => {
            throw err
          })
        })
      })
      Promise.all([...this.promises]).then(() => {
        console.log('done')
      })
    },
    createNode (data) {
      const promise = this.$store.dispatch('$_nodes/createNode', data).then(results => {
        // does the data contain anything other than 'mac' or a private key (_*)?
        if (Object.keys(data).filter(key => key !== 'mac' && key[0] !== '_').length > 0) {
          // chain updateNode
          this.progressTotal += 1
          this.updateNode(data).then(results => {
            // ...
          }).catch((err) => {
            throw err
          })
        }
        return results
      }).catch((err) => {
        throw err
      }).finally(() => {
        this.progressValue += 1
      })
      this.promises.push(promise)
      return promise
    },
    updateNode (data) {
      const promise = this.$store.dispatch('$_nodes/updateNode', data).then(results => {
        // ...
        return results
      }).catch((err) => {
        throw err
      }).finally(() => {
        this.progressValue += 1
      })
      this.promises.push(promise)
      return promise
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
