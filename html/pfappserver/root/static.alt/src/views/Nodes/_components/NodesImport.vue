<template>
  <b-card no-body>
    <b-progress height="2px" :value="progressValue" :max="progressTotal" v-show="progressValue > 0 && progressValue < progressTotal"></b-progress>
    <b-card-header>
      <h4 class="mb-0" v-t="'Import Nodes'"></h4>
    </b-card-header>
    <div class="card-body p-0">
      <b-tabs ref="tabs" v-model="tabIndex" card pills>
        <b-tab v-for="(file, index) in files" :key="file.name + file.lastModified" :title="file.name" no-body>
          <template slot="title">
            <b-button-close class="ml-2 text-white" @click.stop.prevent="closeFile(index)" v-b-tooltip.hover.left.d300 :title="$t('Close File')"><icon name="times"></icon></b-button-close>
            {{ file.name }}
          </template>
          <pf-csv-parse
            :ref="'parser-' + index"
            :file="file"
            :fields="fields"
            :store-name="storeName"
            :default-static-mapping="defaultStaticMapping"
            :events-listen="tabIndex === index"
            :is-loading="isLoading"
            @input="onImport"
          ></pf-csv-parse>
        </b-tab>
        <template slot="tabs">
          <pf-form-upload @load="files = $event" :multiple="true" :cumulative="true" accept="text/*, .csv">{{ $t('Open CSV File') }}</pf-form-upload>
        </template>
        <div slot="empty" class="text-center text-muted">
          <b-container class="my-5">
            <b-row class="justify-content-md-center text-secondary">
                <b-col cols="12" md="auto">
                  <icon v-if="isLoading" name="sync" scale="2" spin></icon>
                  <b-media v-else>
                    <icon name="file" scale="2" slot="aside"></icon>
                    <h4>{{ $t('There are no open CSV files') }}</h4>
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
import {
  pfDatabaseSchema as schema,
  buildValidationFromColumnSchemas
} from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import convert from '@/utils/convert'
import strings from '@/utils/strings'
import {
  required
} from 'vuelidate/lib/validators'
import {
  categoryIdNumberExists, // validate category_id/bypass_role_id (Number) exists
  categoryIdStringExists, // validate category_id/bypass_role_id (String) exists
  userExists // validate user pid exists
} from '@/globals/pfValidators'

export default {
  name: 'nodes-import',
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
      globals: {
        schema: schema
      },
      files: [],
      tabIndex: 0,
      defaultStaticMapping: [{ 'key': 'status', 'value': 'reg' }],
      fields: [
        {
          value: 'mac',
          text: this.$i18n.t('MAC Address'),
          types: [fieldType.SUBSTRING],
          required: true,
          validators: buildValidationFromColumnSchemas(schema.node.mac, { required })
        },
        {
          value: 'status',
          text: this.$i18n.t('Status'),
          types: [fieldType.NODE_STATUS],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.status)
        },
        {
          value: 'autoreg',
          text: this.$i18n.t('Auto Registration'),
          types: [fieldType.YESNO],
          required: false,
          formatter: formatter.yesNoFromString,
          validators: buildValidationFromColumnSchemas(schema.node.autoreg)
        },
        {
          value: 'bandwidth_balance',
          text: this.$i18n.t('Bandwidth Balance'),
          types: [fieldType.PREFIXMULTIPLIER],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.bandwidth_balance)
        },
        {
          value: 'bypass_role_id',
          text: this.$i18n.t('Bypass Role'),
          types: [fieldType.ROLE],
          required: false,
          formatter: formatter.categoryIdFromIntOrString,
          validators: buildValidationFromColumnSchemas({
            [this.$i18n.t('Role does not exist.')]: categoryIdNumberExists,
            [this.$i18n.t('Role does not exist')]: categoryIdStringExists
          })
        },
        {
          value: 'bypass_vlan',
          text: this.$i18n.t('Bypass VLAN'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.bypass_vlan)
        },
        {
          value: 'computername',
          text: this.$i18n.t('Computer Name'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.computername)
        },
        {
          value: 'regdate',
          text: this.$i18n.t('Datetime Registered'),
          types: [fieldType.DATETIME],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.regdate)
        },
        {
          value: 'unregdate',
          text: this.$i18n.t('Datetime Unregistered'),
          types: [fieldType.DATETIME],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.unregdate)
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.notes)
        },
        {
          value: 'pid',
          text: this.$i18n.t('Owner'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.node.pid, {
            [this.$i18n.t('User does not exist.')]: userExists
          })
        },
        {
          value: 'category_id',
          text: this.$i18n.t('Role'),
          types: [fieldType.ROLE],
          required: false,
          formatter: formatter.categoryIdFromIntOrString,
          validators: buildValidationFromColumnSchemas(schema.node.category_id, {
            [this.$i18n.t('Role does not exist.')]: categoryIdNumberExists,
            [this.$i18n.t('Role does not exist.')]: categoryIdStringExists
          })
        },
        {
          value: 'voip',
          text: this.$i18n.t('VoIP'),
          types: [fieldType.YESNO],
          required: false,
          formatter: formatter.yesNoFromString,
          validators: buildValidationFromColumnSchemas(schema.node.voip)
        }
      ],
      progressTotal: 0,
      progressValue: 0,
      isLoading: false
    }
  },
  methods: {
    closeFile (index) {
      this.files.splice(index, 1)
    },
    onImport (values, parser) {
      this.isLoading = true
      // track progress
      let success = 0
      let failed = 0
      this.progressValue = 1
      this.progressTotal = values.length + 1
      // create unique stack
      let stack = {}
      values.forEach(value => {
        value.mac = strings.cleanMac(value.mac) // clean MAC
        stack[value.mac] = value
      })
      // track promise(s)
      Promise.all(Object.values(stack).map(value => {
        if (value.mac) {
          // map child components' tableValue
          let tableValue = parser.tableValues[value._tableValueIndex]
          return this.$store.dispatch('$_nodes/exists', value.mac).then(results => {
            // node exists
            return this.updateNode(Object.assign({ quiet: true }, value)).then(results => {
              if (results.status) {
                tableValue._rowVariant = convert.statusToVariant({ status: results.status })
              } else {
                tableValue._rowVariant = 'success'
              }
              if (results.message) {
                tableValue._rowMessage = this.$i18n.t(results.message)
              }
              success++
              return results
            }).catch(err => {
              failed++
            })
          }).catch(() => {
            // node not exists
            return this.createNode(Object.assign({ quiet: true }, value)).then(results => {
              if (results.status) {
                tableValue._rowVariant = convert.statusToVariant({ status: results.status })
              } else {
                tableValue._rowVariant = 'success'
              }
              if (results.message) {
                tableValue._rowMessage = this.$i18n.t(results.message)
              }
              success++
              return results
            }).catch(err => {
              failed++
            })
          })
        }
      })).then(results => {
        this.$store.dispatch('notification/info', {
          message: results.length + ' ' + this.$i18n.t('nodes imported'),
          skipped: (values.length - success - failed),
          success,
          failed
        })
        this.isLoading = false
      })
    },
    createNode (data) {
      const nodeData = { quiet: true, ...data } // suppress notifications
      // eslint-disable-next-line
      return this.$store.dispatch('$_nodes/createNode', nodeData).then(results => {
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
      const nodeData = { quiet: true, ...data } // suppress notifications
      // eslint-disable-next-line
      return this.$store.dispatch('$_nodes/updateNode', nodeData).then(results => {
        return results
      }).catch(err => {
        throw err
      }).finally(() => {
        this.progressValue += 1
      })
    }
  },
  created () {
    this.$store.dispatch('config/getRoles')
  }
}
</script>

<style lang="scss">
.nav-tabs > li > a,
.nav-pills > li > a {
  margin-right: 0.5rem!important;
}
</style>
