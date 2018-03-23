<template>
    <b-row class="my-1" align-v="center">
        <b-col sm="3"><label class="mb-0" :for="id" v-t="label"></label></b-col>
        <b-col sm="9"><slot/></b-col>
    </b-row>
</template>

<script>

export default {
  name: 'pf-form-row',
  props: {
    id: {
      type: String
    },
    label: {
      type: String
    }
  },
  mounted () {
    // Propagate id to the first element of the default slot
    if (this.id && this.$slots.default.length) {
      this.$slots.default[0].elm.id = this.id
    }
  }
}
</script>

