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
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import { mysqlLimits as sqlLimits } from '@/globals/mysqlLimits'
import convert from '@/utils/convert'
import {
  required,
  macAddress,
  maxLength,
  minLength,
  minValue,
  maxValue
} from 'vuelidate/lib/validators'
import {
  categoryIdNumberExists, // validate category_id/bypass_role_id (Number) exists
  categoryIdStringExists, // validate category_id/bypass_role_id (String) exists
  inArray,
  isDateFormat,
  userExists // validate user pid exists
} from '@/globals/pfValidators'

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
          value: 'autoreg',
          text: this.$i18n.t('Auto Registration'),
          required: false,
          formatter: formatter.yesNoFromString,
          validators: { inArray: inArray(['yes', 'no', 'y', 'n', '1', '0', 'true', 'false']) }
        },
        {
          value: 'bandwidth_balance',
          text: this.$i18n.t('Bandwidth Balance'),
          required: false,
          validators: { minValue: minValue(sqlLimits.ubigint.min), maxValue: maxValue(sqlLimits.ubigint.max) }
        },
        {
          value: 'bypass_role_id',
          text: this.$i18n.t('Bypass Role'),
          required: false,
          formatter: formatter.categoryIdFromIntOrString,
          validators: { categoryIdNumberExists, categoryIdStringExists }
        },
        {
          value: 'bypass_vlan',
          text: this.$i18n.t('Bypass VLAN'),
          required: false,
          validators: { maxLength: maxLength(50) }
        },
        {
          value: 'computername',
          text: this.$i18n.t('Computer Name'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'regdate',
          text: this.$i18n.t('Datetime Registered'),
          required: false,
          validators: { isDateFormat: isDateFormat('YYYY-MM-DD HH:mm:ss') }
        },
        {
          value: 'unregdate',
          text: this.$i18n.t('Datetime Unregistered'),
          required: false,
          validators: { isDateFormat: isDateFormat('YYYY-MM-DD HH:mm:ss') }
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'pid',
          text: this.$i18n.t('Owner'),
          required: false,
          validators: { userExists }
        },
        {
          value: 'category_id',
          text: this.$i18n.t('Role'),
          required: false,
          formatter: formatter.categoryIdFromIntOrString,
          validators: { categoryIdNumberExists, categoryIdStringExists }
        },
        {
          value: 'voip',
          text: this.$i18n.t('VoIP'),
          required: false,
          formatter: formatter.yesNoFromString,
          validators: { inArray: inArray(['yes', 'no', 'y', 'n', '1', '0', 'true', 'false']) }
        }
      ],
      progressTotal: 0,
      progressValue: 0
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
    onImport (values, parser) {
      // track progress
      this.progressValue = 1
      this.progressTotal = values.length + 1
      // track promise(s)
      Promise.all(values.map(value => {
        // map child components' tableValue
        let tableValue = parser.tableValues[value._tableValueIndex]
        return this.$store.dispatch('$_nodes/exists', value.mac).then(results => {
          // node exists
          return this.updateNode(value).then(results => {
            if (results.status) {
              tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            } else {
              tableValue._rowVariant = 'success'
            }
            if (results.message) {
              tableValue._rowMessage = this.$i18n.t(results.message)
            }
            return results
          }).catch(err => {
            throw err
          })
        }).catch(() => {
          // node not exists
          return this.createNode(value).then(results => {
            if (results.status) {
              tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            } else {
              tableValue._rowVariant = 'success'
            }
            if (results.message) {
              tableValue._rowMessage = this.$i18n.t(results.message)
            }
            return results
          }).catch(err => {
            throw err
          })
        })
      })).then(values => {
        this.$store.dispatch('notification/info', {
          message: values.length + ' ' + this.$i18n.t('nodes imported'),
          success: null,
          skipped: null,
          failed: null
        })
      })
    },
    createNode (data) {
      console.log('> createNode', data)
      return this.$store.dispatch('$_nodes/createNode', data).then(results => {
        // does the data contain anything other than 'mac' or a private key (_*)?
        if (Object.keys(data).filter(key => key !== 'mac' && key.charAt(0) !== '_').length > 0) {
          // chain updateNode
          this.progressTotal += 1
          return this.updateNode(data).then(results => {
            return results
          }).catch(err => {
            throw err
          })
        }
        return results
      }).catch(err => {
        throw err
      }).finally(() => {
        this.progressValue += 1
      })
    },
    updateNode (data) {
      console.log('> updateNode')
      return this.$store.dispatch('$_nodes/updateNode', data).then(results => {
        return results
      }).catch(err => {
        throw err
      }).finally(() => {
        this.progressValue += 1
      })
    }
  },
  mounted () {
    if (!this.noInitBindKeys) {
      document.addEventListener('keydown', this.onKeyDown)
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
  },
  beforeDestroy () {
    if (!this.noInitBindKeys) {
      document.removeEventListener('keydown', this.onKeyDown)
    }
  }
}
</script>
