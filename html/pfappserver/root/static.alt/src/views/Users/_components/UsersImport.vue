<template>
  <b-card no-body>
    <b-progress height="2px" :value="progressValue" :max="progressTotal" v-show="progressValue > 0 && progressValue < progressTotal"></b-progress>
    <b-card-header>
      <h4 class="mb-0" v-t="'Import Users'"></h4>
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
import { pfDatabaseSchema as schema } from '@/globals/pfDatabaseSchema'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import convert from '@/utils/convert'
import {
  required,
  maxLength,
  email
} from 'vuelidate/lib/validators'
import {
  inArray,
  isDateFormat,
  sourceExists
} from '@/globals/pfValidators'

export default {
  name: 'UsersImport',
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
      fields: [
        {
          value: 'pid',
          text: this.$i18n.t('PID'),
          required: true,
          validators: { required, maxLength: maxLength(schema.person.pid.maxLength) }
        },
        {
          value: 'title',
          text: this.$i18n.t('Title'),
          required: false,
          validators: { maxLength: maxLength(schema.person.title.maxLength) }
        },
        {
          value: 'firstname',
          text: this.$i18n.t('First Name'),
          required: false,
          validators: { maxLength: maxLength(schema.person.firstname.maxLength) }
        },
        {
          value: 'lastname',
          text: this.$i18n.t('Last Name'),
          required: false,
          validators: { maxLength: maxLength(schema.person.lastname.maxLength) }
        },
        {
          value: 'nickname',
          text: this.$i18n.t('Nickname'),
          required: false,
          validators: { maxLength: maxLength(schema.person.nickname.maxLength) }
        },
        {
          value: 'email',
          text: this.$i18n.t('Email'),
          required: false,
          validators: { email, maxLength: maxLength(schema.person.email.maxLength) }
        },
        {
          value: 'sponsor',
          text: this.$i18n.t('Sponsor'),
          required: false,
          validators: { email, maxLength: maxLength(schema.person.sponsor.maxLength) }
        },
        {
          value: 'anniversary',
          text: this.$i18n.t('Anniversary'),
          required: false,
          validators: { isDateFormat: isDateFormat('YYYY-MM-DD HH:mm:ss') }
        },
        {
          value: 'birthday',
          text: this.$i18n.t('Birthday'),
          required: false,
          validators: { isDateFormat: isDateFormat('YYYY-MM-DD HH:mm:ss') }
        },
        {
          value: 'address',
          text: this.$i18n.t('Address'),
          required: false,
          validators: { maxLength: maxLength(schema.person.address.maxLength) }
        },
        {
          value: 'apartment_number',
          text: this.$i18n.t('Apartment Number'),
          required: false,
          validators: { maxLength: maxLength(schema.person.apartment_number.maxLength) }
        },
        {
          value: 'building_number',
          text: this.$i18n.t('Building Number'),
          required: false,
          validators: { maxLength: maxLength(schema.person.building_number.maxLength) }
        },
        {
          value: 'room_number',
          text: this.$i18n.t('Room Number'),
          required: false,
          validators: { maxLength: maxLength(schema.person.room_number.maxLength) }
        },
        {
          value: 'company',
          text: this.$i18n.t('Company'),
          required: false,
          validators: { maxLength: maxLength(schema.person.company.maxLength) }
        },
        {
          value: 'gender',
          text: this.$i18n.t('Gender'),
          required: false,
          formatter: formatter.genderFromString,
          validators: { inArray: inArray(['m', 'male', 'f', 'female', 'o', 'other']) }
        },
        {
          value: 'lang',
          text: this.$i18n.t('Language'),
          required: false,
          validators: { maxLength: maxLength(schema.person.lang.maxLength) }
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          required: false,
          validators: { maxLength: maxLength(schema.person.notes.maxLength) }
        },
        {
          value: 'portal',
          text: this.$i18n.t('Portal'),
          required: false,
          validators: { maxLength: maxLength(schema.person.portal.maxLength) }
        },
        {
          value: 'psk',
          text: this.$i18n.t('PSK'),
          required: false,
          validators: { maxLength: maxLength(schema.person.psk.maxLength) }
        },
        {
          value: 'source',
          text: this.$i18n.t('Source'),
          required: false,
          validators: { sourceExists, maxLength: maxLength(schema.person.source.maxLength) }
        },
        {
          value: 'telephone',
          text: this.$i18n.t('Telephone'),
          required: false,
          validators: { maxLength: maxLength(schema.person.telephone.maxLength) }
        },
        {
          value: 'cell_phone',
          text: this.$i18n.t('Cellular Phone'),
          required: false,
          validators: { maxLength: maxLength(schema.person.cell_phone.maxLength) }
        },
        {
          value: 'work_phone',
          text: this.$i18n.t('Work Phone'),
          required: false,
          validators: { maxLength: maxLength(schema.person.work_phone.maxLength) }
        },
        {
          value: 'custom_field_1',
          text: this.$i18n.t('Custom Field 1'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_1.maxLength) }
        },
        {
          value: 'custom_field_2',
          text: this.$i18n.t('Custom Field 2'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_2.maxLength) }
        },
        {
          value: 'custom_field_3',
          text: this.$i18n.t('Custom Field 3'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_3.maxLength) }
        },
        {
          value: 'custom_field_4',
          text: this.$i18n.t('Custom Field 4'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_4.maxLength) }
        },
        {
          value: 'custom_field_5',
          text: this.$i18n.t('Custom Field 5'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_5.maxLength) }
        },
        {
          value: 'custom_field_6',
          text: this.$i18n.t('Custom Field 6'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_6.maxLength) }
        },
        {
          value: 'custom_field_7',
          text: this.$i18n.t('Custom Field 7'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_7.maxLength) }
        },
        {
          value: 'custom_field_8',
          text: this.$i18n.t('Custom Field 8'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_8.maxLength) }
        },
        {
          value: 'custom_field_9',
          text: this.$i18n.t('Custom Field 9'),
          required: false,
          validators: { maxLength: maxLength(schema.person.custom_field_9.maxLength) }
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
        return this.$store.dispatch('$_users/exists', value.pid).then(results => {
          // node exists
          return this.updateUser(value).then(results => {
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
          return this.createUser(value).then(results => {
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
          message: values.length + ' ' + this.$i18n.t('users imported'),
          success: null,
          skipped: null,
          failed: null
        })
      })
    },
    createUser (data) {
      return this.$store.dispatch('$_users/createUser', data).then(results => {
        // does the data contain anything other than 'pid' or a private key (_*)?
        if (Object.keys(data).filter(key => key !== 'pid' && key.charAt(0) !== '_').length > 0) {
          // chain updateUser
          this.progressTotal += 1
          return this.updateUser(data).then(results => {
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
    updateUser (data) {
      return this.$store.dispatch('$_users/updateUser', data).then(results => {
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
    this.$store.dispatch('config/getSources')
  },
  beforeDestroy () {
    if (!this.noInitBindKeys) {
      document.removeEventListener('keydown', this.onKeyDown)
    }
  }
}
</script>
