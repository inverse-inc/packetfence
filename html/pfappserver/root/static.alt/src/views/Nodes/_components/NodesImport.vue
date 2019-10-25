<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Import Nodes'"></h4>
    </b-card-header>
    <div class="card-body p-0">
      <b-tabs ref="tabs" v-model="tabIndex" card pills>
        <b-tab v-for="(file, index) in files" :key="file.name + file.lastModified"
          :title="file.name" :title-link-class="(tabIndex === index) ? ['bg-primary', 'text-light'] : ['bg-light', 'text-primary']"
          no-body
        >
          <template v-slot:title>
            <b-button-close class="ml-2" :class="(tabIndex === index) ? 'text-white' : 'text-primary'" @click.stop.prevent="closeFile(index)" v-b-tooltip.hover.left.d300 :title="$t('Close File')">
              <icon name="times" class="align-top ml-1"></icon>
            </b-button-close>
            {{ file.name }}
          </template>
          <pf-csv-import
            :ref="'import-' + index"
            :file="file"
            :fields="fields"
            :store-name="storeName"
            :default-static-mapping="defaultStaticMapping"
            :events-listen="tabIndex === index"
            :is-loading="isLoading"
            :import-promise="importPromise"
            hover
            striped
          ></pf-csv-import>
        </b-tab>
        <template v-slot:tabs-end>
          <pf-form-upload @files="files = $event" @focus="tabIndex = $event" :multiple="true" :cumulative="true" accept="text/*, .csv">{{ $t('Open CSV File') }}</pf-form-upload>
        </template>
        <template v-slot:empty>
          <div class="text-center text-muted">
            <b-container class="my-5">
              <b-row class="justify-content-md-center text-secondary">
                  <b-col cols="12" md="auto">
                    <icon v-if="isLoading" name="sync" scale="2" spin></icon>
                    <b-media v-else>
                      <template v-slot:aside><icon name="file" scale="2"></icon></template>
                      <h4>{{ $t('There are no open CSV files') }}</h4>
                    </b-media>
                  </b-col>
              </b-row>
            </b-container>
          </div>
        </template>
      </b-tabs>
    </div>
  </b-card>
</template>

<script>
import pfCSVImport from '@/components/pfCSVImport'
import pfFormUpload from '@/components/pfFormUpload'
import {
  pfDatabaseSchema as schema,
  buildValidationFromColumnSchemas
} from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
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
    'pf-csv-import': pfCSVImport,
    pfFormUpload
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
          validators: buildValidationFromColumnSchemas({
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
      isLoading: false
    }
  },
  methods: {
    abortFile (index) {
      this.files[index].reader.abort()
    },
    closeFile (index) {
      const file = this.files[index]
      file.close()
    },
    importPromise (payload, dryRun) {
      return new Promise((resolve, reject) => {
        this.$store.dispatch(`${this.storeName}/bulkImport`, payload).then(result => {
          // do something with the result, then Promise.resolve to continue processing
          resolve(result)
        }).catch(err => {
          // do something with the error, then Promise.reject to stop processing
          reject(err)
        })
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
