<template>
  <b-form @submit.prevent="save()">
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close" v-b-tooltip.hover.left.d300 :title="$t('Close [ESC]')"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('Admin API Audit Log Entry')}} <strong v-text="id"></strong></h4>
      </b-card-header>
      <pf-form-row :column-label="$t('User Name')">{{ item.user_name }}</pf-form-row>
      <pf-form-row :column-label="$t('Action')">{{ item.action }}</pf-form-row>
      <pf-form-row :column-label="$t('Object ID')">{{ item.object_id }}</pf-form-row>
      <pf-form-row :column-label="$t('URL')">{{ item.url }}</pf-form-row>
      <pf-form-row :column-label="$t('Method')">{{ item.method }}</pf-form-row>
      <pf-form-row :column-label="$t('Status Code')">{{ item.status }}</pf-form-row>
      <pf-form-row :column-label="$t('Request')">{{ item.request }}</pf-form-row>
    </b-card>
  </b-form>
</template>

<script>
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'AdminApiAuditLogView',
  components: {
    pfFormRow
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: String // from router
  },
  data () {
    return {
      item: {},
      tabIndex: 0,
      tabTitle: ''
    }
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    escapeKey () {
      return this.$store.getters['events/escapeKey']
    }
  },
  methods: {
    init () {
      this.$store.dispatch(`${this.storeName}/getItem`, this.id).then(item => {
        this.item = item
      })
    },
    ifTab (set) {
      return this.$refs.tabs && set.includes(this.$refs.tabs.tabs[this.tabIndex].title)
    },
    close () {
      this.$router.push({ name: 'admin_api_audit_logs' })
    }
  },
  created () {
    this.init()
  },
  watch: {
    escapeKey (pressed) {
      if (pressed) this.close()
    }
  }
}
</script>
