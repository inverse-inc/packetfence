<template>
  <b-card no-body>
    <b-card-header>
      Hosts
    </b-card-header>
    <pre>{{ {data} }}</pre>
  </b-card>
</template>
<script>
const components = {}

const props = {
  data: {
    type: Array
  }
}

const setup = () => {

  return {}
}

// @vue/component
export default {
  name: 'base-data-hosts',
  components,
  props,
  setup
}
</script>