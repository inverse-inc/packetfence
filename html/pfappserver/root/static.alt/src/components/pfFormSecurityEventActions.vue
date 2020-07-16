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
          v-model="inputValue.target_category" :options="metaOptions('target_category')"></pf-form-chosen>
        <pf-form-chosen class="my-1" :column-label="$t('Access Duration')"
          v-model="inputValue.access_duration" :options="metaOptions('access_duration')"></pf-form-chosen>
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
          v-model="inputValue.vlan" :options="metaOptions('vlan')"></pf-form-chosen>
        <pf-form-chosen class="my-1" :column-label="$t('Template to use')"
          v-model="inputValue.template" :options="metaOptions('template')"></pf-form-chosen>
        <pf-form-input
          v-model="inputValue.button_text"
          :column-label="$t('Button Text')"
          :text="$t('Text displayed on the security event form to hosts.')"></pf-form-input>
        <pf-form-input
          v-model="inputValue.redirect_url"
          :column-label="$t('Redirection URL')"
          :text="$t('Destination URL where PacketFence will forward the device. By default it will use the Redirection URL from the connection profile configuration.')"></pf-form-input>
        <pf-form-range-toggle
          v-model="inputValue.auto_enable"
          :column-label="$t('Auto Enable')"
          :text="$t('Specifies if a host can self remediate the security event (enable network button) or if they can not and must call the help desk.')"
          :values="{ checked: 'Y', unchecked: 'N' }"></pf-form-range-toggle>
        <pf-form-input type="number"
          v-model="inputValue.max_enable"
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
            v-model="inputValue.user_mail_message"
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
            v-model="inputValue.external_command"
            :text="$t('Script need to be readable and executable by pf user. You can use the following variables in your script launch command:<ul><li><b>$mac:</b> MAC address of the endpoint</li><li><b>$ip:</b> IP address of the endpoint</li><li><b>$vid:</b> ID of the security event</li></ul>')"></pf-form-input>
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
          v-model="inputValue.vclose" :options="metaOptions('vclose')"></pf-form-chosen>
      </b-col>
    </b-row>

  </div>
</template>

<script>
import pfFormChosen from './pfFormChosen'
import pfFormInput from './pfFormInput'
import pfFormRangeToggle from './pfFormRangeToggle'
import pfFormTextarea from './pfFormTextarea'
import pfMixinForm from '@/components/pfMixinForm'

export default {
  name: 'pf-form-security-event-actions',
  components: {
    pfFormChosen,
    pfFormInput,
    pfFormRangeToggle,
    pfFormTextarea
  },
  mixins: [
    pfMixinForm
  ],
  props: {
    value: {
      default: () => ({ actions: [], target_category: false })
    },
    meta: {
      type: Object,
      default: () => ({})
    }
  },
  computed: {
    inputValue: {
      get () {
        if (this.formStoreName && this.formNamespace) {
          return this.formStoreValue // use FormStore
        } else {
          return this.value // use native (v-model)
        }
      },
      set (newValue = null) {
        if (this.formStoreName) {
          this.formStoreValue = newValue // use FormStore
        } else {
          this.$emit('input', newValue) // use native (v-model)
        }
      }
    },
    unreg: {
      get () {
        const { actions = [] } = this.inputValue || {}
        return actions.includes('unreg')
      },
      set (newValue) {
        if (newValue) {
          // add unreg
          this.addValueAction('unreg')
          // remove autoreg
          this.removeValueAction('autoreg')
        } else {
          // remove unreg
          this.removeValueAction('unreg')
        }
      }
    },
    autoreg: {
      get () {
        const { actions = [] } = this.inputValue || {}
        return actions.includes('autoreg')
      },
      set (newValue) {
        if (newValue) {
          // add autoreg
          this.addValueAction('autoreg')
          // add role
          this.addValueAction('role')
          // remove unreg
          this.removeValueAction('unreg')
        } else {
          // remove autoreg
          this.removeValueAction('autoreg')
          // remove role
          this.removeValueAction('role')
        }
      }
    },
    isolate: {
      get () {
        const { actions = [] } = this.inputValue || {}
        return actions.includes('reevaluate_access')
      },
      set (newValue) {
        if (newValue) {
          this.addValueAction('reevaluate_access')
        } else {
          this.removeValueAction('reevaluate_access')
        }
      }
    },
    email_admin: {
      get () {
        const { actions = [] } = this.inputValue || {}
        return actions.includes('email_admin')
      },
      set (newValue) {
        if (newValue) {
          this.addValueAction('email_admin')
        } else {
          this.removeValueAction('email_admin')
        }
      }
    },
    email_user: {
      get () {
        const { actions = [] } = this.inputValue || {}
        return actions.includes('email_user')
      },
      set (newValue) {
        if (newValue) {
          this.addValueAction('email_user')
        } else {
          this.removeValueAction('email_user')
        }
      }
    },
    external: {
      get () {
        const { actions = [] } = this.inputValue || {}
        return actions.includes('external')
      },
      set (newValue) {
        if (newValue) {
          this.addValueAction('external')
        } else {
          this.removeValueAction('external')
        }
      }
    },
    close: {
      get () {
        const { actions = [] } = this.inputValue || {}
        return actions.includes('close')
      },
      set (newValue) {
        if (newValue) {
          this.addValueAction('close')
        } else {
          this.removeValueAction('close')
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
    },
    addValueAction (action) {
      this.removeValueAction(action) // remove dups
      this.inputValue.actions.push(action)
    },
    removeValueAction (action) {
      this.inputValue.actions = this.inputValue.actions.filter(a => a !== action)
    }
  },
  watch: {
    'inputValue.target_category': { // add 'role' to actions if target_category is set, otherwise remove
      handler: function (a) {
        const { actions = [] } = this.inputValue || {}
        if (actions.length > 0) {
          if (a) {
            this.addValueAction('role')
          } else {
            this.removeValueAction('role')
          }
        }
      },
      immediate: true
    }
  }
}
</script>
