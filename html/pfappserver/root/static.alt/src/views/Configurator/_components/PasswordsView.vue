<template>
    <b-card no-body class="mt-3" v-if="database.root_pass || administrator.password">
        <b-card-header>
        <h4 class="d-inline mb-0" v-t="'Passwords'"></h4>
        <small class="text-muted ml-2" v-t="'Make sure to keep them in a secure place'"></small>
        </b-card-header>
        <div class="card-body">
        <template v-if="database.root_pass">
            <b-form-group
              :label="$t('Database Root Account')"
              label-size="lg"
              class="m-0"
              label-class="text-left offset-sm-3"></b-form-group>
            <pf-form-row :column-label="$t('Username')">root</pf-form-row>
            <pf-form-row :column-label="$t('Password')">
              <code>{{ database.root_pass }}</code>
              <b-button size="sm" variant="outline-primary" class="ml-2 text-nowrap" @click.stop.prevent="clipboard(database.root_pass)">{{ $t('Copy to Clipboard') }}</b-button>
            </pf-form-row>
        </template>
        <template v-if="database.pass">
            <b-form-group
              :label="$t('Database User Account')"
              label-size="lg"
              class="m-0"
              label-class="text-left offset-sm-3"></b-form-group>
            <pf-form-row :column-label="$t('Username')">{{ database.user }}</pf-form-row>
            <pf-form-row :column-label="$t('Password')">
              <code>{{ database.pass }}</code>
              <b-button size="sm" variant="outline-primary" class="ml-2 text-nowrap" @click.stop.prevent="clipboard(database.pass)">{{ $t('Copy to Clipboard') }}</b-button>
            </pf-form-row>
        </template>
        <template v-if="administrator.password">
            <b-form-group
              :label="$t('Administrator Account')"
              label-size="lg"
              class="m-0"
              label-class="text-left offset-sm-3"></b-form-group>
            <pf-form-row :column-label="$t('Username')">{{ administrator.pid }}</pf-form-row>
            <pf-form-row :column-label="$t('Password')">
              <code>{{ administrator.password }}</code>
              <b-button size="sm" variant="outline-primary" class="ml-2 text-nowrap" @click.stop.prevent="clipboard(administrator.password)">{{ $t('Copy to Clipboard') }}</b-button>
            </pf-form-row>
        </template>
        </div>
    </b-card>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'passwords-view',
  components: {
    pfFormRow
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    administrator () {
      return this.$store.getters[`${this.storeName}/$formNS`]('administrator')
    },
    database () {
      return this.$store.getters[`${this.storeName}/$formNS`]('database')
    }
  },
  methods: {
    clipboard (text) {
      try {
        navigator.clipboard.writeText(text).then(() => {
          this.$store.dispatch('notification/info', { message: this.$i18n.t('Password copied to clipboard') })
        }).catch(() => {
          this.$store.dispatch('notification/danger', { message: this.$i18n.t('Could not copy password to clipboard.') })
        })
      } catch (e) {
        this.$store.dispatch('notification/danger', { message: this.$i18n.t('Clipboard not supported.') })
      }
    }
  }
}
</script>
