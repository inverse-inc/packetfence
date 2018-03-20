
<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0">User {{ pid }}</h4>
    </b-card-header>
  </b-card>
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
    }
  },
  computed: {
  },
  methods: {
  },
  mounted () {

  }
}
</script>

