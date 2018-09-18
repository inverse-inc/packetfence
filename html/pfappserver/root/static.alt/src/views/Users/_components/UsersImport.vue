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
      files: [],
      tabIndex: 0,
      fields: [
        {
          value: 'pid',
          text: this.$i18n.t('PersonID'),
          required: true,
          validators: { required, maxLength: maxLength(255) }
        },
        {
          value: 'title',
          text: this.$i18n.t('Title'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'firstname',
          text: this.$i18n.t('First Name'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'lastname',
          text: this.$i18n.t('Last Name'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'nickname',
          text: this.$i18n.t('Nickname'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'email',
          text: this.$i18n.t('Email'),
          required: false,
          validators: { email, maxLength: maxLength(255) }
        },
        {
          value: 'sponsor',
          text: this.$i18n.t('Sponsor'),
          required: false,
          validators: { email, maxLength: maxLength(255) }
        },
        {
          value: 'anniversary',
          text: this.$i18n.t('Anniversary'),
          required: false,
          validators: { isDateFormat: isDateFormat('YYYY-MM-DD HH:mm:ss'), maxLength: maxLength(255) }
        },
        {
          value: 'birthday',
          text: this.$i18n.t('Birthday'),
          required: false,
          validators: { isDateFormat: isDateFormat('YYYY-MM-DD HH:mm:ss'), maxLength: maxLength(255) }
        },
        {
          value: 'address',
          text: this.$i18n.t('Address'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'apartment_number',
          text: this.$i18n.t('Apartment Number'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'building_number',
          text: this.$i18n.t('Building Number'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'room_number',
          text: this.$i18n.t('Room Number'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'company',
          text: this.$i18n.t('Company'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'gender',
          text: this.$i18n.t('Gender'),
          required: false,
          formatter: formatter.genderFromString,
          validators: { inArray: inArray(['m', 'male', 'f', 'female']) }
        },
        {
          value: 'lang',
          text: this.$i18n.t('Language'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'notes',
          text: this.$i18n.t('Notes'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'portal',
          text: this.$i18n.t('Portal'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'psk',
          text: this.$i18n.t('PSK'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'source',
          text: this.$i18n.t('Source'),
          required: false,
          validators: { sourceExists, maxLength: maxLength(255) }
        },
        {
          value: 'telephone',
          text: this.$i18n.t('Telephone'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'cell_phone',
          text: this.$i18n.t('Cellular Phone'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'work_phone',
          text: this.$i18n.t('Work Phone'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_1',
          text: this.$i18n.t('Custom Field 1'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_2',
          text: this.$i18n.t('Custom Field 2'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_3',
          text: this.$i18n.t('Custom Field 3'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_4',
          text: this.$i18n.t('Custom Field 4'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_5',
          text: this.$i18n.t('Custom Field 5'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_6',
          text: this.$i18n.t('Custom Field 6'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_7',
          text: this.$i18n.t('Custom Field 7'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_8',
          text: this.$i18n.t('Custom Field 8'),
          required: false,
          validators: { maxLength: maxLength(255) }
        },
        {
          value: 'custom_field_9',
          text: this.$i18n.t('Custom Field 9'),
          required: false,
          validators: { maxLength: maxLength(255) }
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
    onImport (values) {
      // track progress
      this.progressValue = 1
      this.progressTotal = values.length + 1
      // track promise(s)
      Promise.all(values.map(value => {
        return this.$store.dispatch('$_nodes/exists', value.mac).then(results => {
          console.log('exists')
          // node exists
          return this.updateUser(value).then(results => {
            console.log('updateUser', value)
            value._tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            if (results.message) {
              value._tableValue._rowMessage = this.$i18n.t(results.message)
            }
            return results
          }).catch(err => {
            throw err
          })
        }).catch(() => {
          console.log('not exists')
          // node not exists
          return this.createUser(value).then(results => {
            value._tableValue._rowVariant = convert.statusToVariant({ status: results.status })
            if (results.message) {
              value._tableValue._rowMessage = this.$i18n.t(results.message)
            }
            return results
          }).catch(err => {
            throw err
          })
        })
      })).then(values => {
        console.log(['promise values', values])
      }).catch(reason => {
        console.log(['promises reason', reason])
      })
      console.log('onImport done')
    },
    createUser (data) {
      console.log('> createUser', data)
      return this.$store.dispatch('$_nodes/createUser', data).then(results => {
        // does the data contain anything other than 'mac' or a private key (_*)?
        if (Object.keys(data).filter(key => key !== 'mac' && key.charAt(0) !== '_').length > 0) {
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
      console.log('> updateUser')
      return this.$store.dispatch('$_nodes/updateUser', data).then(results => {
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
