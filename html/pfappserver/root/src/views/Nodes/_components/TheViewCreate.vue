<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Create Node'"></h4>
    </b-card-header>
        <the-form-create />
    </b-card>
</template>
<script>
import TheFormCreate from './TheFormCreate'

const components = {
  TheFormCreate
}


// @vue/component
export default {
  name: 'the-view-create',
  inheritAttrs: false,
  components
}
</script>
