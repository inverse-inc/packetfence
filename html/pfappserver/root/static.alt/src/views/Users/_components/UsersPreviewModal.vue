<template>
  <b-modal id="usersListModal" size="lg" :title="$t('The following users have been created')"
    centered no-close-on-backdrop no-close-on-esc lazy scrollable
    @hidden="localValue = false" @shown="localValue = true"
  >
    <b-table
      :items="users"
      :fields="visibleUsersFields"
      :sortBy="usersSortBy"
      :sortDesc="usersSortDesc"
      show-empty responsive striped></b-table>
    <template v-slot:modal-footer>
      <div class="w-100">
        <b-button variant="primary" class="float-right" @click="preview()">{{ $i18n.t('Preview') }}</b-button>
      </div>
    </template>
  </b-modal>
</template>

<script>
export default {
  name: 'users-preview-modal',
  data () {
    return {
      localValue: false,
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
      this.localValue = false
      this.$router.push({ name: 'usersPreview' })
    }
  },
  watch: {
    users (a) {
      if (a.find(user => user.email)) {
        this.usersFields.find(field => field.key === 'email').visible = true
      }
    },
    localValue: {
      handler (a, b) {
        if (a !== b) {
          this.$emit('input', a)
          if (a) {
            this.$bvModal.show('usersListModal')
          } else {
            this.$bvModal.hide('usersListModal')
          }
        }
      }
    },
    value: {
      handler (a) {
        this.localValue = a
      }
    },
    immediate: true
  }
}
</script>
