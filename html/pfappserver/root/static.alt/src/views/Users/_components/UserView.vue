
<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('User') }} <strong v-text="pid"></strong></h4>
      </b-card-header>
      <b-tabs ref="tabs" v-model="tabIndex" card>

        <b-tab title="Profile" active>
          <template slot="title">
            {{ $t('Profile') }}
          </template>
          <b-row>
            <b-col>
              <pf-form-input :column-label="$t('Username (PID)')"
                readonly
                v-model.trim="userContent.pid"
                :vuelidate="$v.userContent.pid"
                text="The username to use for login to the captive portal."/>
              <pf-form-input :column-label="$t('Password')"
                v-model="userContent.password"
                :vuelidate="$v.userContent.password"
                type="password"
                text="Leave empty to keep current password."/>
              <pf-form-input :column-label="$t('Login remaining')"
                v-model="userContent.login_remaining"
                :vuelidate="$v.userContent.login_remaining"
                type="number"
                text="Leave empty to allow unlimited logins."/>
              <pf-form-input :column-label="$t('Email')"
                v-model.trim="userContent.email"
                :vuelidate="$v.userContent.email"
              />
              <pf-form-input :column-label="$t('Sponsor')"
                v-model.trim="userContent.sponsor"
                :vuelidate="$v.userContent.sponsor"
              />
              <pf-form-chosen :column-label="$t('Gender')"
                v-model="userContent.gender"
                label="text"
                track-by="value"
                :placeholder="$t('Choose gender')"
                :options="[{text:$t('Male'), value:'m'}, {text:$t('Female'), value:'f'}, {text:$t('Other'), value:'o'}]"
              ></pf-form-chosen>
              <pf-form-input :column-label="$t('Title')"
                v-model="userContent.title"
                :vuelidate="$v.userContent.title"
              />
              <pf-form-input :column-label="$t('Firstname')"
                v-model="userContent.firstname"
                :vuelidate="$v.userContent.firstname"
              />
              <pf-form-input :column-label="$t('Lastname')"
                v-model="userContent.lastname"
                :vuelidate="$v.userContent.lastname"
              />
              <pf-form-input :column-label="$t('Nickname')"
                v-model="userContent.nickname"
                :vuelidate="$v.userContent.nickname"
              />
              <pf-form-input :column-label="$t('Company')"
                v-model="userContent.company"
                :vuelidate="$v.userContent.company"
              />
              <pf-form-input :column-label="$t('Telephone number')"
                v-model="userContent.telephone"
                :filter="globals.regExp.stringPhone"
                :vuelidate="$v.userContent.telephone"
              />
              <pf-form-input :column-label="$t('Cellphone number')"
                v-model="userContent.cell_phone"
                :filter="globals.regExp.stringPhone"
                :vuelidate="$v.userContent.cell_phone"
              />
              <pf-form-input :column-label="$t('Workphone number')"
                v-model="userContent.work_phone"
                :filter="globals.regExp.stringPhone"
                :vuelidate="$v.userContent.work_phone"
              />
              <pf-form-input :column-label="$t('Apartment number')"
                v-model="userContent.apartment_number"
                :filter="globals.regExp.stringPhone"
                :vuelidate="$v.userContent.apartment_number"
              />
              <pf-form-input :column-label="$t('Building Number')"
                v-model="userContent.building_number"
                :filter="globals.regExp.stringPhone"
                :vuelidate="$v.userContent.building_number"
              />
              <pf-form-input :column-label="$t('Room Number')"
                v-model="userContent.room_number"
                :filter="globals.regExp.stringPhone"
                :vuelidate="$v.userContent.room_number"
              />
              <pf-form-textarea :column-label="$t('Address')" rows="4" max-rows="6"
                v-model="userContent.address"
                :vuelidate="$v.userContent.address"
              />
              <pf-form-datetime :column-label="$t('Anniversary')"
                v-model="userContent.anniversary"
                :config="{format: 'YYYY-MM-DD'}"
                :vuelidate="$v.userContent.anniversary"
              />
              <pf-form-datetime :column-label="$t('Birthday')"
                v-model="userContent.birthday"
                :config="{format: 'YYYY-MM-DD'}"
                :vuelidate="$v.userContent.birthday"
              />
              <pf-form-input :column-label="$t('Psk')"
                v-model="userContent.psk"
                :vuelidate="$v.userContent.psk"
              />
              <pf-form-textarea :column-label="$t('Notes')"
                v-model="userContent.notes"
                :vuelidate="$v.userContent.notes"
                rows="3" max-rows="3"
              />
            </b-col>
          </b-row>
        </b-tab>

        <b-tab title="Custom Fields">
          <template slot="title">
            {{ $t('Custom Fields') }}
          </template>
          <b-form-row>
            <b-col>
              <pf-form-input v-for="i in 9" v-model="userContent['custom_field_' + i]" :column-label="'Custom Field ' + i" :key="i"/>
            </b-col>
          </b-form-row>
        </b-tab>

        <b-tab title="Devices">
          <template slot="title">
            {{ $t('Devices') }} <b-badge pill v-if="userContent.nodes && userContent.nodes.length > 0" variant="light" class="ml-1">{{ userContent.nodes.length }}</b-badge>
          </template>
          <b-table stacked="sm" :items="userContent.nodes" :fields="nodeFields" :sortBy="nodeSortBy" :sortDesc="nodeSortDesc" show-empty responsive striped>
            <template slot="status" slot-scope="node">
              <b-badge pill variant="success" v-if="node.item.status === 'reg'">{{ $t('registered') }}</b-badge>
              <b-badge pill variant="secondary" v-else-if="node.item.status === 'unreg'">{{ $t('unregistered') }}</b-badge>
              <span v-else>{{ node.item.status }}</span>
            </template>
            <template slot="mac" slot-scope="node">
              <b-button variant="link" :to="`../../node/${node.item.mac}`">{{ node.item.mac }}</b-button>
            </template>
            <template slot="empty">
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No devices found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>

        <b-tab title="Security Events">
          <template slot="title">
            {{ $t('Security Events') }} <b-badge pill v-if="userContent.security_events && userContent.security_events.length > 0" variant="light" class="ml-1">{{ userContent.security_events.length }}</b-badge>
          </template>
          <b-table stacked="sm" :items="userContent.security_events" :fields="securityEventFields" :sortBy="securityEventSortBy" :sortDesc="securityEventSortDesc" show-empty responsive striped>
            <template slot="status" slot-scope="securityEvent">
              <b-badge pill variant="success" v-if="securityEvent.item.status === 'open'">{{ $t('open') }}</b-badge>
              <b-badge pill variant="secondary" v-else-if="securityEvent.item.status === 'closed'">{{ $t('closed') }}</b-badge>
              <span v-else>{{ securityEvent.item.status }}</span>
            </template>
            <template slot="mac" slot-scope="securityEvent">
              <b-button variant="link" :to="`../../node/${securityEvent.item.mac}`">{{ securityEvent.item.mac }}</b-button>
            </template>
            <template slot="buttons" slot-scope="securityEvent">
              <span class="float-right text-nowrap">
                <b-button size="sm" v-if="securityEvent.item.status === 'open'" variant="outline-danger" :disabled="isLoading" @click="closeSecurityEvent(securityEvent)">{{ $t('Close Event') }}</b-button>
              </span>
            </template>
            <template slot="empty">
              <pf-empty-table :isLoading="isLoading" text="">{{ $t('No security events found') }}</pf-empty-table>
            </template>
          </b-table>
        </b-tab>
      </b-tabs>
      <b-card-footer @mouseenter="$v.userContent.$touch()">
        <pf-button-save class="mr-1" v-if="ifTab(['Profile', 'Custom Fields'])" :disabled="invalidForm" :isLoading="isLoading"/>
        <pf-button-delete class="mr-3" v-if="ifTab(['Profile', 'Custom Fields']) && !isDefaultUser" :disabled="isLoading" :confirm="$t('Delete User?')" @on-delete="deleteUser()"/>
        <b-button class="mr-1" v-if="ifTab(['Devices']) && !isDefaultUser" variant="outline-primary" :disabled="isLoading || !hasNodes" @click="unassignNodes()">{{ $t('Unassign Nodes') }}</b-button>
        <b-button class="mr-1" v-if="ifTab(['Security Events'])" variant="outline-primary" :disabled="isLoading || !hasOpenSecurityEvents" @click="closeSecurityEvents()">{{ $t('Close all security events') }}</b-button>
      </b-card-footer>
    </b-card>
  </b-form>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfButtonDelete from '@/components/pfButtonDelete'
import pfEmptyTable from '@/components/pfEmptyTable'
import pfFormChosen from '@/components/pfFormChosen'
import pfFormDatetime from '@/components/pfFormDatetime'
import pfFormInput from '@/components/pfFormInput'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormToggle from '@/components/pfFormToggle'
import { pfFormatters as formatter } from '@/globals/pfFormatters'
import {
  required,
  minLength
} from 'vuelidate/lib/validators'
import {
  and,
  not,
  conditional,
  userExists
} from '@/globals/pfValidators'
import { pfRegExp as regExp } from '@/globals/pfRegExp'
import {
  pfDatabaseSchema as schema,
  buildValidationFromTableSchemas
} from '@/globals/pfDatabaseSchema'

const { validationMixin } = require('vuelidate')

export default {
  name: 'UserView',
  components: {
    pfButtonSave,
    pfButtonDelete,
    pfEmptyTable,
    pfFormChosen,
    pfFormDatetime,
    pfFormInput,
    pfFormTextarea,
    pfFormToggle
  },
  mixins: [
    validationMixin
  ],
  props: {
    pid: String
  },
  data () {
    return {
      globals: {
        regExp: regExp,
        schema: schema
      },
      tabIndex: 0,
      tabTitle: '',
      userContent: {},
      nodeFields: [
        {
          key: 'status',
          label: this.$i18n.t('Status'),
          sortable: true
        },
        {
          key: 'mac',
          label: this.$i18n.t('MAC'),
          sortable: true
        },
        {
          key: 'computername',
          label: this.$i18n.t('Computer Name'),
          sortable: true
        },
        {
          key: 'device_class',
          label: this.$i18n.t('Device Class'),
          sortable: true
        },
        {
          key: 'device_type',
          label: this.$i18n.t('Device Type'),
          sortable: true
        },
        {
          key: 'regdate',
          label: this.$i18n.t('Registration Date'),
          sortable: true,
          formatter: formatter.datetimeIgnoreZero
        },
        {
          key: 'unregdate',
          label: this.$i18n.t('Unregistration Date'),
          sortable: true,
          formatter: formatter.datetimeIgnoreZero
        }
      ],
      nodeSortBy: 'status',
      nodeSortDesc: false,
      securityEventFields: [
        {
          key: 'status',
          label: this.$i18n.t('Status'),
          sortable: true
        },
        {
          key: 'security_event_id',
          label: this.$i18n.t('Event'),
          sortable: true,
          formatter: formatter.securityEventIdToDesc
        },
        {
          key: 'mac',
          label: this.$i18n.t('MAC'),
          sortable: true
        },
        {
          key: 'notes',
          label: this.$i18n.t('Description'),
          sortable: true
        },
        {
          key: 'start_date',
          label: this.$i18n.t('Start Date'),
          sortable: true,
          formatter: formatter.datetimeIgnoreZero
        },
        {
          key: 'release_date',
          label: this.$i18n.t('Release Date'),
          sortable: true,
          formatter: formatter.datetimeIgnoreZero
        },
        {
          key: 'buttons',
          label: '',
          sortable: false,
          locked: true
        }
      ],
      securityEventSortBy: 'status',
      securityEventSortDesc: false
    }
  },
  validations () {
    return {
      userContent: buildValidationFromTableSchemas(
        schema.person, // use `person` table schema
        schema.password, // use `password` table schema
        { sponsor: schema.person.sponsor }, // `sponsor` column exists in both `person` and `password` tables, fix: overload
        {
          // additional custom validations ...
          pid: {
            [this.$i18n.t('Username required.')]: required,
            [this.$i18n.t('Username exists.')]: not(and(required, userExists, conditional(this.userContent.pid !== this.pid)))
          },
          email: {
            [this.$i18n.t('Email address required.')]: required
          },
          password: {
            [this.$i18n.t('Minimum 6 characters.')]: minLength(6)
          },
          psk: {
            [this.$i18n.t('Minimum 8 characters.')]: minLength(8)
          }
        }
      )
    }
  },
  computed: {
    node () {
      return this.$store.state.$_users.users[this.pid]
    },
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    },
    invalidForm () {
      return this.$v.userContent.$invalid || this.$store.getters['$_users/isLoading']
    },
    hasNodes () {
      return this.userContent.nodes.length > 0
    },
    hasOpenSecurityEvents () {
      return this.userContent.security_events.findIndex(securityEvent => securityEvent.status === 'open') > -1
    },
    isDefaultUser () {
      return this.userContent.pid === 'default'
    }
  },
  methods: {
    ifTab (set) {
      return this.$refs.tabs && set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    },
    close () {
      this.$router.push({ name: 'users' })
    },
    save () {
      this.$store.dispatch('$_users/updateUser', this.userContent).then(response => {
        this.close()
      })
    },
    deleteUser () {
      this.$store.dispatch('$_users/deleteUser', this.pid).then(response => {
        this.close()
      })
    },
    closeSecurityEvent (securityEvent) {
      console.log('closeSecurityEvent', securityEvent)
    },
    closeSecurityEvents () {
      console.log('closeSecurityEvents')
    },
    unassignNodes () {
      this.$store.dispatch('$_users/unassignUserNodes', this.pid).then(response => {
        this.userContent.nodes = []
      })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  mounted () {
    this.$store.dispatch('$_users/getUser', this.pid).then(user => {
      this.userContent = user
    })
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>
