<template>
    <b-card no-body class="mt-3" v-if="db.root_pass || administrator.password">
        <b-card-header>
        <h4 class="d-inline mb-0" v-t="'Passwords'"></h4>
        <small class="text-muted ml-2" v-t="'Make sure to keep them in a secure place'"></small>
        </b-card-header>
        <div class="card-body">
        <template v-if="db.root_pass">
            <pf-form-row :column-label="$t('Database Root Account')" label-class="col-form-label-lg offset-sm-3"></pf-form-row>
            <pf-form-row :column-label="$t('Username')">root</pf-form-row>
            <pf-form-row :column-label="$t('Password')">{{ db.root_pass }}</pf-form-row>
        </template>
        <template v-if="administrator.password">
            <pf-form-row :column-label="$t('Administrator Account')" label-class="col-form-label-lg"></pf-form-row>
            <pf-form-row :column-label="$t('Username')">{{ administrator.pid }}</pf-form-row>
            <pf-form-row :column-label="$t('Password')">{{ administrator.password }}</pf-form-row>
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
    db () {
      return this.$store.getters[`${this.storeName}/$formNS`]('db')
    }
  }
}
</script>
