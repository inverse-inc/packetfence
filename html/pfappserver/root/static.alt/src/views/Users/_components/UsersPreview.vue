<template>
  <b-card no-body>
    <b-card-header>
      <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
      <h4 class="mb-0" v-t="'Preview Messages for Created Users'"></h4>
    </b-card-header>
    <b-card-body>
      <div class="pb-5 d-print-none">
        <pf-form-input :column-label="$t('Subject')"
          v-model="emailSubject"
          :text="$t('The subject used for email messages.')"/>
        <hr/>
      </div>
      <b-container class="my-5" v-if="isLoading">
        <b-row class="justify-content-md-center text-secondary">
            <b-col cols="12" md="auto">
            <icon name="circle-notch" scale="1.5" spin></icon>
            </b-col>
        </b-row>
      </b-container>
      <div class="shadow mb-4" v-for="template in usersTemplates" :key="template.pid">
        <b-container class="d-print-none" v-if="template.email" fluid>
          <pf-form-row :column-label="$t('Subject')">{{ emailSubject }}</pf-form-row>
          <pf-form-row :column-label="$t('From')">{{ emailFrom }}</pf-form-row>
          <pf-form-row :column-label="$t('To')">{{ template.email }}</pf-form-row>
        </b-container>
        <b-embed type="iframe" aspect="4by3" :src="iframeContent(template.html)"></b-embed>
      </div>
    </b-card-body>
    <b-card-footer>
      <b-button variant="outline-primary" @click="send()" v-if="canSend" class="mr-1">{{ $i18n.t('Send') }}</b-button>
      <b-button variant="outline-primary" @click="print()">{{ $i18n.t('Print') }}</b-button>
    </b-card-footer>
  </b-card>
</template>

<script>
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'
import pfMixinEscapeKey from '@/components/pfMixinEscapeKey'

export default {
  name: 'UsersPreview',
  mixins: [
    pfMixinEscapeKey
  ],
  components: {
    pfFormInput,
    pfFormRow
  },
  data () {
    return {
      emailSubject: '',
      emailFrom: '',
      usersSortBy: 'pid',
      usersSortDesc: false,
      usersTemplates: []
    }
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters['$_users/isLoading']
    },
    users () {
      return this.$store.state[this.storeName].createdUsers
    },
    canSend () {
      return this.users.find(user => user.email)
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'users' })
    },
    iframeContent (html) {
      return 'data:text/html;charset=utf-8,' + escape(html)
    },
    send () {
      Promise.all(this.users.filter(user => user.email).map(user => {
        const data = {
          ...user,
          ...{
            subject: this.emailSubject
          }
        }
        return this.$store.dispatch('$_users/sendEmail', data)
      })).then(results => {
        this.$store.dispatch('notification/info', {
          message: this.$i18n.t('{count} messages sent', { count: results.length }),
          success: null,
          skipped: null,
          failed: null
        })
      })
    },
    print () {
      window.print()
    }
  },
  created () {
    if (this.users.length === 0) {
      this.$router.push({ name: 'users' })
    }
    this.$store.dispatch('config/getBaseGeneral').then(general => {
      this.emailSubject = `${general.domain}: Guest account creation information`
    })
    this.$store.dispatch('config/getBaseAlerting').then(alerting => {
      if (alerting.emailaddr) {
        this.emailFrom = alerting.emailaddr
      } else {
        this.$store.dispatch('config/getBaseGeneral').then(general => {
          this.emailFrom = `root@${general.hostname}.${general.domain}`
        })
      }
    })
    this.users.forEach(user => {
      return this.$store.dispatch('$_users/previewEmail', user).then(response => {
        this.usersTemplates.push({ pid: user.pid, email: user.email, html: response.body })
      })
    })
  }
}
</script>

<style lang="scss">
@media print {
  .card-header,
  .card-footer,
  .notifications,
  .notifications-toasts {
    display: none !important;
  }
  .card {
    border: 0 !important;
  }
  .card-body {
    flex: none !important;
    padding: 0 !important;
    .shadow {
      box-shadow: none !important;
    }
  }
  .embed-responsive {
    height: 10in;
    page-break-after: always;
  }
}
</style>
