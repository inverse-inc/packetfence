
<template>
  <b-form>
    <b-card no-body>
      <b-card-header>
        <b-button-close @click="close"><icon name="times"></icon></b-button-close>
        <h4 class="mb-0">{{ $t('User') }} {{ pid }}</h4>
      </b-card-header>
      <b-card-body>
       {{ user.notes }}
      </b-card-body>
    </b-card>
  </b-form>
</template>

<script>
import ToggleButton from '@/components/ToggleButton'

export default {
  name: 'UserView',
  components: {
    'toggle-button': ToggleButton
  },
  props: {
    pid: String
  },
  data () {
    return {
      user: {}
    }
  },
  computed: {
  },
  methods: {
    close () {
      this.$router.push({ name: 'users' })
    }
  },
  mounted () {
    this.$store.dispatch('$_users/getUser', this.pid).then(data => {
      this.user = data
    })
  }
}
</script>

