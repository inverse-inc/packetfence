<template>
  <div>
    <b-card no-body>
      <b-progress height="2px" :value="progressValue" :max="progressTotal" v-show="progressValue > 0 && progressValue < progressTotal"></b-progress>
      <b-card-header>
        <h4 class="mb-0" v-t="'Import Users'"></h4>
      </b-card-header>
      <div class="card-body p-0">
        <b-tabs ref="tabs" v-model="tabIndex" card pills>
          <b-tab v-for="(file, index) in files" :key="file.name + file.lastModified" :title="file.name" no-body>
            <template slot="title">
              <b-button-close class="ml-2 text-white" @click.stop.prevent="closeFile(index)" v-b-tooltip.hover.left.d300 :title="$t('Close File')"><icon name="times"></icon></b-button-close>
              {{ $t(file.name) }}
            </template>
            <pf-csv-parse
              :ref="'parser-' + index"
              :file="file"
              :fields="fields"
              :store-name="storeName"
              :events-listen="tabIndex === index"
              :is-loading="isLoading"
              @input="onImport"
            >
              <b-tab :title="$t('Import Options')">
                <b-form-group label-cols="3" :label="$t('Registration Window')">
                  <b-row>
                    <b-col>
                      <pf-form-datetime v-model="localUser.valid_from"
                        :min="new Date()"
                        :config="{datetimeFormat: 'YYYY-MM-DD'}"
                        :vuelidate="$v.localUser.valid_from"
                      />
                    </b-col>
                    <p class="pt-2"><icon name="long-arrow-alt-right"></icon></p>
                    <b-col>
                      <pf-form-datetime v-model="localUser.expiration"
                        :min="new Date()"
                        :config="{datetimeFormat: 'YYYY-MM-DD'}"
                        :vuelidate="$v.localUser.expiration"
                      />
                    </b-col>
                  </b-row>
                </b-form-group>
                <pf-form-fields
                  v-model="localUser.actions"
                  :column-label="$t('Actions')"
                  :button-label="$t('Add Action')"
                  :field="actionField"
                  :vuelidate="$v.localUser.actions"
                  :invalid-feedback="[
                    { [$t('One or more errors exist.')]: !$v.localUser.actions.anyError }
                  ]"
                  @validations="actionsValidations = $event"
                  sortable
                ></pf-form-fields>
                <pf-form-row align-v="start" :column-label="$t('Password Options')">
                  <b-alert show variant="info">
                    {{ $t('When no password is imported, a random password is generated using the following criteria.') }}
                  </b-alert>
                  <b-row>
                    <b-col cols="6">
                      <pf-form-input class="p-0" type="range" min="6" max="32"
                        v-model="passwordGenerator.pwlength"
                        :column-label="$t('Length')"
                        :text="$t('{count} characters', { count: passwordGenerator.pwlength })"/>
                      <pf-form-toggle
                        v-model="passwordGenerator.upper"
                        :column-label="$t('Uppercase')"
                        :text="$t('Include uppercase characters')">ABC</pf-form-toggle>
                      <pf-form-toggle
                        v-model="passwordGenerator.lower"
                        :column-label="$t('Lowercase')"
                        :text="$t('Include lowercase characters')">abc</pf-form-toggle>
                      <pf-form-toggle
                        v-model="passwordGenerator.digits"
                        :column-label="$t('Digits')"
                        :text="$t('Include digits')">123</pf-form-toggle>
                    </b-col>
                    <b-col cols="6">
                      <pf-form-toggle
                        v-model="passwordGenerator.special"
                        :column-label="$t('Special')"
                        :text="$t('Include special characters')">!@#</pf-form-toggle>
                      <pf-form-toggle
                        v-model="passwordGenerator.brackets"
                        :column-label="$t('Brackets/Parenthesis')"
                        :text="$t('Include brackets')">({&lt;</pf-form-toggle>
                      <pf-form-toggle
                        v-model="passwordGenerator.high"
                        :column-label="$t('Accentuated')"
                        :text="$t('Include accentuated characters')">äæ±</pf-form-toggle>
                      <pf-form-toggle
                        v-model="passwordGenerator.ambiguous"
                        :column-label="$t('Ambiguous')"
                        :text="$t('Include ambiguous characters')">0Oo</pf-form-toggle>
                    </b-col>
                  </b-row>
                </pf-form-row>
              </b-tab>
            </pf-csv-parse>
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

    <users-preview-modal v-model="showUsersPreviewModal" :store-name="storeName" />

  </div>
</template>

<script>
import { format } from 'date-fns'
import pfCSVParse from '@/components/pfCSVParse'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import pfFormToggle from '@/components/pfFormToggle'
import pfFormUpload from '@/components/pfFormUpload'
import pfProgress from '@/components/pfProgress'
import UsersPreviewModal from './UsersPreviewModal'
import { pfConfigurationActions } from '@/globals/configuration/pfConfiguration'
import {
  pfDatabaseSchema as schema,
  buildValidationFromColumnSchemas
} from '@/globals/pfDatabaseSchema'
import { pfFieldType as fieldType } from '@/globals/pfField'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import convert from '@/utils/convert'
import password from '@/utils/password'
import {
  required
} from 'vuelidate/lib/validators'
import {
  and,
  not,
  conditional,
  compareDate,
  sourceExists
} from '@/globals/pfValidators'

const { validationMixin } = require('vuelidate')

export default {
  name: 'users-import',
  components: {
    'pf-csv-parse': pfCSVParse,
    pfFormDatetime,
    pfFormFields,
    pfFormInput,
    pfFormRow,
    pfFormToggle,
    pfFormUpload,
    pfProgress,
    UsersPreviewModal
  },
  mixins: [
    validationMixin
  ],
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
          types: [fieldType.SUBSTRING],
          required: true,
          validators: buildValidationFromColumnSchemas(schema.person.pid, { required })
        },
        {
          value: 'password',
          text: this.$i18n.t('Password'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.password.password)
        },
        {
          value: 'title',
          text: this.$i18n.t('Title'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.title)
        },
        {
          value: 'firstname',
          text: this.$i18n.t('First Name'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.firstname)
        },
        {
          value: 'lastname',
          text: this.$i18n.t('Last Name'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.lastname)
        },
        {
          value: 'nickname',
          text: this.$i18n.t('Nickname'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.nickname)
        },
        {
          value: 'email',
          text: this.$i18n.t('Email'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.email)
        },
        {
          value: 'sponsor',
          text: this.$i18n.t('Sponsor'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.sponsor)
        },
        {
          value: 'anniversary',
          text: this.$i18n.t('Anniversary'),
          types: [fieldType.DATE],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.anniversary)
        },
        {
          value: 'birthday',
          text: this.$i18n.t('Birthday'),
          types: [fieldType.DATE],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.birthday)
        },
        {
          value: 'address',
          text: this.$i18n.t('Address'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.address)
        },
        {
          value: 'apartment_number',
          text: this.$i18n.t('Apartment Number'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.apartment_number)
        },
        {
          value: 'building_number',
          text: this.$i18n.t('Building Number'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.building_number)
        },
        {
          value: 'room_number',
          text: this.$i18n.t('Room Number'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.room_number)
        },
        {
          value: 'company',
          text: this.$i18n.t('Company'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.company)
        },
        {
          value: 'gender',
          text: this.$i18n.t('Gender'),
          types: [fieldType.GENDER],
          required: false,
          formatter: formatter.genderFromString,
          validators: buildValidationFromColumnSchemas(schema.person.gender)
        },
        {
          value: 'lang',
          text: this.$i18n.t('Language'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.lang)
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.notes)
        },
        {
          value: 'portal',
          text: this.$i18n.t('Portal'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.portal)
        },
        {
          value: 'psk',
          text: this.$i18n.t('PSK'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.psk)
        },
        {
          value: 'source',
          text: this.$i18n.t('Source'),
          types: [fieldType.SOURCE],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.source, { [this.$i18n.t('Invalid source.')]: sourceExists })
        },
        {
          value: 'telephone',
          text: this.$i18n.t('Telephone'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.telephone)
        },
        {
          value: 'cell_phone',
          text: this.$i18n.t('Cellular Phone'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.cell_phone)
        },
        {
          value: 'work_phone',
          text: this.$i18n.t('Work Phone'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.work_phone)
        },
        {
          value: 'custom_field_1',
          text: this.$i18n.t('Custom Field 1'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_1)
        },
        {
          value: 'custom_field_2',
          text: this.$i18n.t('Custom Field 2'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_2)
        },
        {
          value: 'custom_field_3',
          text: this.$i18n.t('Custom Field 3'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_3)
        },
        {
          value: 'custom_field_4',
          text: this.$i18n.t('Custom Field 4'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_4)
        },
        {
          value: 'custom_field_5',
          text: this.$i18n.t('Custom Field 5'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_5)
        },
        {
          value: 'custom_field_6',
          text: this.$i18n.t('Custom Field 6'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_6)
        },
        {
          value: 'custom_field_7',
          text: this.$i18n.t('Custom Field 7'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_7)
        },
        {
          value: 'custom_field_8',
          text: this.$i18n.t('Custom Field 8'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_8)
        },
        {
          value: 'custom_field_9',
          text: this.$i18n.t('Custom Field 9'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: buildValidationFromColumnSchemas(schema.person.custom_field_9)
        }
      ],
      localUser: {
        valid_from: format(new Date(), 'YYYY-MM-DD'),
        expiration: null,
        actions: []
      },
      showUsersPreviewModal: false,
      passwordGenerator: {
        pwlength: 8,
        upper: true,
        lower: true,
        digits: true,
        special: false,
        brackets: false,
        high: false,
        ambiguous: false
      },
      actionField: {
        component: pfFieldTypeValue,
        attrs: {
          typeLabel: this.$i18n.t('Select action type'),
          valueLabel: this.$i18n.t('Select action value'),
          fields: [
            pfConfigurationActions.set_access_duration,
            pfConfigurationActions.set_access_level,
            // pfConfigurationActions.set_bandwidth_balance,
            pfConfigurationActions.mark_as_sponsor,
            pfConfigurationActions.set_role,
            pfConfigurationActions.set_tenant_id,
            // pfConfigurationActions.set_time_balance,
            pfConfigurationActions.set_unreg_date
          ]
        }
      },
      actionsValidations: {},
      progressTotal: 0,
      progressValue: 0,
      isLoading: false
    }
  },
  validations () {
    return {
      localUser: {
        valid_from: {
          [this.$i18n.t('Start date required.')]: conditional(!!this.localUser.valid_from && this.localUser.valid_from !== '0000-00-00'),
          [this.$i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD'),
          [this.$i18n.t('Date must be less than or equal to end date.')]: not(and(required, conditional(this.localUser.valid_from), not(compareDate('<=', this.localUser.expiration, 'YYYY-MM-DD'))))
        },
        expiration: {
          [this.$i18n.t('End date required.')]: conditional(!!this.localUser.expiration && this.localUser.expiration !== '0000-00-00'),
          [this.$i18n.t('Date must be today or later.')]: compareDate('>=', new Date(), 'YYYY-MM-DD'),
          [this.$i18n.t('Date must be greater than or equal to start date.')]: not(and(required, conditional(this.localUser.expiration), not(compareDate('>=', this.localUser.valid_from, 'YYYY-MM-DD'))))
        },
        actions: this.actionsValidations
      }
    }
  },
  methods: {
    closeFile (index) {
      this.files.splice(index, 1)
    },
    onImport (values, parser) {
      this.isLoading = true
      let createdUsers = []
      // track progress
      let success = 0
      let failed = 0
      this.progressValue = 1
      this.progressTotal = values.length + 1
      // create unique stack
      let stack = {}
      values.forEach(value => {
        stack[value.pid] = value
      })
      // track promise(s)
      Promise.all(Object.values(stack).map(value => {
        // map child components' tableValue
        let tableValue = parser.tableValues[value._tableValueIndex]
        const data = {
          ...this.localUser,
          ...value
        }
        return this.$store.dispatch(`${this.storeName}/exists`, value.pid).then(results => {
          // user exists
          return this.updateUser(data).then(results => {
            if (results.status) {
              tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            } else {
              tableValue._rowVariant = 'success'
            }
            if (results.message) {
              tableValue._rowMessage = this.$i18n.t(results.message)
            }
            createdUsers.push(data)
            success++
            return results
          }).catch(err => {
            failed++
          })
        }).catch(() => {
          // user not exists
          if (!('password' in value)) {
            data.password = password.generate(this.passwordGenerator)
          }
          return this.createUser(data).then(results => {
            if (results.status) {
              tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            } else {
              tableValue._rowVariant = 'success'
            }
            if (results.message) {
              tableValue._rowMessage = this.$i18n.t(results.message)
            }
            createdUsers.push(data)
            success++
            return results
          }).catch(err => {
            failed++
          })
        })
      })).then(results => {
        this.$store.dispatch('notification/info', {
          message: results.length + ' ' + this.$i18n.t('users imported'),
          skipped: (values.length - success - failed),
          success,
          failed
        })
        this.$store.commit(`${this.storeName}/CREATED_USERS_REPLACED`, createdUsers)
        this.showUsersPreviewModal = true
        this.isLoading = false
      })
    },
    createUser (data) {
      const userData = { quiet: true, ...data } // suppress notifications
      return this.$store.dispatch(`${this.storeName}/createUser`, userData).then(results => {
        return this.$store.dispatch(`${this.storeName}/createPassword`, userData).then(results => {
          return results
        }).catch(err => {
          throw err
        })
      }).catch(err => {
        throw err
      }).finally(() => {
        this.progressValue += 1
      })
    },
    updateUser (data) {
      const userData = { quiet: true, ...data } // suppress notifications
      return this.$store.dispatch(`${this.storeName}/updateUser`, userData).then(results => {
        return this.$store.dispatch(`${this.storeName}/updatePassword`, userData).then(results => {
          return results
        }).catch(err => {
          throw err
        })
      }).catch(err => {
        throw err
      }).finally(() => {
        this.progressValue += 1
      })
    }
  },
  created () {
    this.$store.dispatch('config/getSources')
  }
}
</script>

<style lang="scss">
.nav-tabs > li > a,
.nav-pills > li > a {
  margin-right: 0.5rem!important;
}
</style>
