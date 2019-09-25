<template>
  <b-modal id="usersListModal" size="lg" :title="$t('The following user have been created')" :visible="value"
    no-close-on-backdrop no-close-on-esc lazy scrollable>
    <b-table
      :items="users"
      :fields="visibleUsersFields"
      :sortBy="usersSortBy"
      :sortDesc="usersSortDesc"
      show-empty responsive striped></b-table>
    <div v-slot:modal-footer class="w-100">
      <b-button variant="primary" class="float-right" @click="preview()" :disabled="isLoading">{{ $i18n.t('Preview') }}</b-button>
    </div>
  </b-modal>
</template>

<script>
import pfFormInput from '@/components/pfFormInput'
import pfFormRow from '@/components/pfFormRow'

export default {
  name: 'users-preview-modal',
  components: {
    pfFormInput,
    pfFormRow
  },
  data () {
    return {
      emailSubject: '',
      emailFrom: '',
      usersFields: [
        {
          key: 'pid',
          label: this.$i18n.t('Username'),
          sortable: true,
          visible: true
        },
        {
          key: 'email',
          label: this.$i18n.t('Email'),
          sortable: true,
          visible: false
        },
        {
          key: 'password',
          label: this.$i18n.t('Password'),
          sortable: false,
          visible: true
        }
      ],
      usersSortBy: 'pid',
      usersSortDesc: false,
      usersTemplates: []
    }
  },
  props: {
    value: {
      type: Boolean,
      default: false
    },
    storeName: {
      type: String,
      default: null,
      required: true
    }
  },
  computed: {
    users () {
      return this.$store.state[this.storeName].createdUsers
    },
    visibleUsersFields () {
      return this.usersFields.filter(field => field.visible)
    }
  },
  methods: {
    preview () {
      // this.$bvModal.hide('usersListModal')
      this.value = false
      this.$router.push({ name: 'usersPreview' })
    }
  },
  watch: {
    users (a, b) {
      if (a.find(user => user.email)) {
        this.usersFields.find(field => field.key === 'email').visible = true
      }
    }
  }
}
</script>
