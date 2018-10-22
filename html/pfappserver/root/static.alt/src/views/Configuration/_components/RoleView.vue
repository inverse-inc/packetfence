<script>
import BaseView from './_lib/BaseView'
const { required, alphaNum, integer } = require('vuelidate/lib/validators')

export default {
  name: 'RoleView',
  extends: BaseView,
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: String,
      default: null
    }
  },
  data () {
    return {
      role: {} // will be overloaded with the data from the store
    }
  },
  validations () {
    return {
      role: {
        id: {
          [this.$i18n.t('Name is required')]: required,
          [this.$i18n.t('Alphanumeric value required')]: alphaNum
        },
        max_nodes_per_pid: {
          [this.$i18n.t('Value required')]: required,
          [this.$i18n.t('Integer value required')]: integer
        }
      }
    }
  },
  computed: {
    isNew () {
      return this.id === null
    },
    isLoading () {
      return this.$store.getters['$_roles/isLoading']
    },
    invalidForm () {
      return this.$v.role.$invalid || this.$store.getters['$_roles/isWaiting']
    }
  },
  methods: {
    close () {
      this.$router.push({ name: 'roles' })
    },
    create () {
      this.$store.dispatch('$_roles/createRole', this.role).then(response => {
        this.close()
      })
    },
    save () {
      this.$store.dispatch('$_roles/updateRole', this.role).then(response => {
        this.close()
      })
    },
    deleteRole () {
      this.$store.dispatch('$_roles/deleteRole', this.id).then(response => {
        this.close()
      })
    },
    onKeyup (event) {
      switch (event.keyCode) {
        case 27: // escape
          this.close()
      }
    }
  },
  created () {
    if (this.id) {
      this.$store.dispatch('$_roles/getRole', this.id).then(data => {
        this.role = Object.assign({}, data)
      })
    }
  },
  mounted () {
    document.addEventListener('keyup', this.onKeyup)
  },
  beforeDestroy () {
    document.removeEventListener('keyup', this.onKeyup)
  }
}
</script>
