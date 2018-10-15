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
import { pfFieldType as fieldType } from '@/globals/pfField'
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
          types: [fieldType.SUBSTRING],
          required: true,
          validators: {
            required,
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.pid)]: maxLength(schema.person.pid.maxLength)
          }
        },
        {
          value: 'title',
          text: this.$i18n.t('Title'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.title)]: maxLength(schema.person.title.maxLength)
          }
        },
        {
          value: 'firstname',
          text: this.$i18n.t('First Name'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.firstname)]: maxLength(schema.person.firstname.maxLength)
          }
        },
        {
          value: 'lastname',
          text: this.$i18n.t('Last Name'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.lastname)]: maxLength(schema.person.lastname.maxLength)
          }
        },
        {
          value: 'nickname',
          text: this.$i18n.t('Nickname'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.nickname)]: maxLength(schema.person.nickname.maxLength)
          }
        },
        {
          value: 'email',
          text: this.$i18n.t('Email'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Valid email address required.')]: email,
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.email)]: maxLength(schema.person.email.maxLength)
          }
        },
        {
          value: 'sponsor',
          text: this.$i18n.t('Sponsor'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Valid email address required.')]: email,
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.sponsor)]: maxLength(schema.person.sponsor.maxLength)
          }
        },
        {
          value: 'anniversary',
          text: this.$i18n.t('Anniversary'),
          types: [fieldType.DATE],
          required: false,
          validators: {
            [this.$i18n.t('Invalid date.')]: isDateFormat(schema.person.anniversary.format)
          }
        },
        {
          value: 'birthday',
          text: this.$i18n.t('Birthday'),
          types: [fieldType.DATE],
          required: false,
          validators: {
            [this.$i18n.t('Invalid date.')]: isDateFormat(schema.person.birthday.format)
          }
        },
        {
          value: 'address',
          text: this.$i18n.t('Address'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.address)]: maxLength(schema.person.address.maxLength)
          }
        },
        {
          value: 'apartment_number',
          text: this.$i18n.t('Apartment Number'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.apartment_number)]: maxLength(schema.person.apartment_number.maxLength)
          }
        },
        {
          value: 'building_number',
          text: this.$i18n.t('Building Number'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.building_number)]: maxLength(schema.person.building_number.maxLength)
          }
        },
        {
          value: 'room_number',
          text: this.$i18n.t('Room Number'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.room_number)]: maxLength(schema.person.room_number.maxLength)
          }
        },
        {
          value: 'company',
          text: this.$i18n.t('Company'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.company)]: maxLength(schema.person.company.maxLength)
          }
        },
        {
          value: 'gender',
          text: this.$i18n.t('Gender'),
          types: [fieldType.GENDER],
          required: false,
          formatter: formatter.genderFromString,
          validators: {
            [this.$i18n.t('Invalid gender.')]: inArray(['m', 'male', 'f', 'female', 'o', 'other'])
          }
        },
        {
          value: 'lang',
          text: this.$i18n.t('Language'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.lang)]: maxLength(schema.person.lang.maxLength)
          }
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.notes)]: maxLength(schema.person.notes.maxLength)
          }
        },
        {
          value: 'portal',
          text: this.$i18n.t('Portal'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.portal)]: maxLength(schema.person.portal.maxLength)
          }
        },
        {
          value: 'psk',
          text: this.$i18n.t('PSK'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.psk)]: maxLength(schema.person.psk.maxLength)
          }
        },
        {
          value: 'source',
          text: this.$i18n.t('Source'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            sourceExists,
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.source)]: maxLength(schema.person.source.maxLength)
          }
        },
        {
          value: 'telephone',
          text: this.$i18n.t('Telephone'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.telephone)]: maxLength(schema.person.telephone.maxLength)
          }
        },
        {
          value: 'cell_phone',
          text: this.$i18n.t('Cellular Phone'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.cell_phone)]: maxLength(schema.person.cell_phone.maxLength)
          }
        },
        {
          value: 'work_phone',
          text: this.$i18n.t('Work Phone'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.work_phone)]: maxLength(schema.person.work_phone.maxLength)
          }
        },
        {
          value: 'custom_field_1',
          text: this.$i18n.t('Custom Field 1'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_1)]: maxLength(schema.person.custom_field_1.maxLength)
          }
        },
        {
          value: 'custom_field_2',
          text: this.$i18n.t('Custom Field 2'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_2)]: maxLength(schema.person.custom_field_2.maxLength)
          }
        },
        {
          value: 'custom_field_3',
          text: this.$i18n.t('Custom Field 3'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_3)]: maxLength(schema.person.custom_field_3.maxLength)
          }
        },
        {
          value: 'custom_field_4',
          text: this.$i18n.t('Custom Field 4'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_4)]: maxLength(schema.person.custom_field_4.maxLength)
          }
        },
        {
          value: 'custom_field_5',
          text: this.$i18n.t('Custom Field 5'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_5)]: maxLength(schema.person.custom_field_5.maxLength)
          }
        },
        {
          value: 'custom_field_6',
          text: this.$i18n.t('Custom Field 6'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_6)]: maxLength(schema.person.custom_field_6.maxLength)
          }
        },
        {
          value: 'custom_field_7',
          text: this.$i18n.t('Custom Field 7'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_7)]: maxLength(schema.person.custom_field_7.maxLength)
          }
        },
        {
          value: 'custom_field_8',
          text: this.$i18n.t('Custom Field 8'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_8)]: maxLength(schema.person.custom_field_8.maxLength)
          }
        },
        {
          value: 'custom_field_9',
          text: this.$i18n.t('Custom Field 9'),
          types: [fieldType.SUBSTRING],
          required: false,
          validators: {
            [this.$i18n.t('Maximum {maxLength} characters.', schema.person.custom_field_9)]: maxLength(schema.person.custom_field_9.maxLength)
          }
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
