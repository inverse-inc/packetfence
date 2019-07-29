<template>
  <div>

    <b-row no-gutters class="border-bottom">
      <b-col sm="auto">
        <pf-form-range-toggle v-model="unreg"></pf-form-range-toggle>
      </b-col>
      <b-col cols="3">
        <div class="col-form-label text-left ml-2" v-t="'Unregister'"></div>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col sm="auto">
        <pf-form-range-toggle v-model="autoreg"></pf-form-range-toggle>
      </b-col>
      <b-col cols="3">
        <div class="col-form-label text-left ml-2" v-t="'Register'"></div>
      </b-col>
      <b-col>
        <pf-form-chosen class="my-1" :column-label="$t('Target Role')"
          v-model="value.target_category" :options="metaOptions('target_category')"></pf-form-chosen>
        <pf-form-chosen class="my-1" :column-label="$t('Access Duration')"
          v-model="value.access_duration" :options="metaOptions('access_duration')"></pf-form-chosen>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col sm="auto">
        <pf-form-range-toggle v-model="isolate"></pf-form-range-toggle>
      </b-col>
      <b-col cols="3">
        <div class="col-form-label text-left ml-2" v-t="'Isolate'"></div>
      </b-col>
      <b-col>
        <pf-form-chosen class="my-1" :column-label="$t('Role while isolated')"
          v-model="value.vlan" :options="metaOptions('vlan')"></pf-form-chosen>
        <pf-form-chosen class="my-1" :column-label="$t('Template to use')"
          v-model="value.template" :options="metaOptions('template')"></pf-form-chosen>
        <pf-form-input
          v-model="value.button_text"
          :column-label="$t('Button Text')"
          :text="$t('Text displayed on the security event form to hosts.')"></pf-form-input>
        <pf-form-input
          v-model="value.redirect_url"
          :column-label="$t('Redirection URL')"
          :text="$t('Destination URL where PacketFence will forward the device. By default it will use the Redirection URL from the connection profile configuration.')"></pf-form-input>
        <pf-form-range-toggle
          v-model="value.auto_enable"
          :column-label="$t('Auto Enable')"
          :text="$t('Specifies if a host can self remediate the security event (enable network button) or if they can not and must call the help desk.')"
          :values="{ checked: 'Y', unchecked: 'N' }"></pf-form-range-toggle>
        <pf-form-input type="number"
          v-model="value.max_enable"
          :column-label="$t('Max Enables')"
          :text="$t('Number of times a host will be able to try and self remediate before they are locked out and have to call the help desk. This is useful for users who just click through security event pages.')"></pf-form-input>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col sm="auto">
        <pf-form-range-toggle v-model="email_admin"></pf-form-range-toggle>
      </b-col>
      <b-col cols="3">
        <div class="col-form-label text-left ml-2" v-t="'Email administrator'"></div>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col sm="auto">
        <pf-form-range-toggle v-model="email_user"></pf-form-range-toggle>
      </b-col>
      <b-col cols="3">
        <div class="col-form-label text-left ml-2" v-t="'Email endpoint owner'"></div>
      </b-col>
      <b-col>
          <pf-form-textarea class="my-1"
            v-model="value.user_mail_message"
            :column-label="$t('Additional message')"
            :rows="4"></pf-form-textarea>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col sm="auto">
        <pf-form-range-toggle v-model="external"></pf-form-range-toggle>
      </b-col>
      <b-col cols="3">
        <div class="col-form-label text-left ml-2" v-t="'Execute script'"></div>
      </b-col>
      <b-col>
          <pf-form-input class="my-1"
            v-model="value.external_command"
            :text="$t('You can use the following variables in your script launch command:<ul><li><b>$mac:</b> MAC address of the endpoint</li><li><b>$ip:</b> IP address of the endpoint</li><li><b>$vid:</b> ID of the security event</li></ul>')"></pf-form-input>
      </b-col>
    </b-row>

    <b-row no-gutters class="border-bottom">
      <b-col sm="auto">
        <pf-form-range-toggle v-model="close"></pf-form-range-toggle>
      </b-col>
      <b-col cols="3">
        <div class="col-form-label text-left ml-2" v-t="'Close another security event'"></div>
      </b-col>
      <b-col>
        <pf-form-chosen class="my-1" :column-label="$t('Security event to close')"
          v-model="value.vclose" :options="metaOptions('vclose')"></pf-form-chosen>
      </b-col>
    </b-row>

  </div>
</template>

<script>
import pfFormChosen from './pfFormChosen'
import pfFormInput from './pfFormInput'
import pfFormRangeToggle from './pfFormRangeToggle'
import pfFormTextarea from './pfFormTextarea'

export default {
  name: 'pf-form-security-event-actions',
  components: {
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle,
    pfFormTextarea
  },
  props: {
    value: {
      default: {}
    },
    meta: {
      type: Object,
      default: () => {}
    }
  },
  computed: {
    unreg: {
      get () {
        return this.value.actions && this.value.actions.includes('unreg')
      },
      set (newValue) {
        let index
        if (newValue) {
          // add unreg
          this.value.actions.push('unreg')
          // remove autoreg
          index = this.value.actions.indexOf('autoreg')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        } else {
          // add unreg
          index = this.value.actions.indexOf('unreg')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        }
      }
    },
    autoreg: {
      get () {
        return this.value.actions && this.value.actions.includes('autoreg')
      },
      set (newValue) {
        let index
        if (newValue) {
          // add autoreg
          this.value.actions.push('autoreg')
          // add role
          this.value.actions.push('role')
          // remove unreg
          index = this.value.actions.indexOf('unreg')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        } else {
          // remove autoreg
          index = this.value.actions.indexOf('autoreg')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
          // remove role
          index = this.value.actions.indexOf('role')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        }
      }
    },
    isolate: {
      get () {
        return this.value.actions && this.value.actions.includes('reevaluate_access')
      },
      set (newValue) {
        let index
        if (newValue) {
          this.value.actions.push('reevaluate_access')
        } else {
          index = this.value.actions.indexOf('reevaluate_access')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        }
      }
    },
    email_admin: {
      get () {
        return this.value.actions && this.value.actions.includes('email_admin')
      },
      set (newValue) {
        let index
        if (newValue) {
          this.value.actions.push('email_admin')
        } else {
          index = this.value.actions.indexOf('email_admin')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        }
      }
    },
    email_user: {
      get () {
        return this.value.actions && this.value.actions.includes('email_user')
      },
      set (newValue) {
        let index
        if (newValue) {
          this.value.actions.push('email_user')
        } else {
          index = this.value.actions.indexOf('email_user')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        }
      }
    },
    external: {
      get () {
        return this.value.actions && this.value.actions.includes('external')
      },
      set (newValue) {
        let index
        if (newValue) {
          this.value.actions.push('external')
        } else {
          index = this.value.actions.indexOf('external')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        }
      }
    },
    close: {
      get () {
        return this.value.actions && this.value.actions.includes('close')
      },
      set (newValue) {
        let index
        if (newValue) {
          this.value.actions.push('close')
        } else {
          index = this.value.actions.indexOf('close')
          if (index >= 0) {
            this.value.actions.splice(index, 1)
          }
        }
      }
    }
  },
  methods: {
    metaOptions (field) {
      let options = []
      if (this.meta && this.meta[field]) {
        const { allowed } = this.meta[field]
        if (allowed) {
          options = allowed
        }
      }
      return options
    }
  }
}
</script>
