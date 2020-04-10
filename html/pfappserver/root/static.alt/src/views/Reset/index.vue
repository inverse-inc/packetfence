<template>
</template>

<script>
export default {
  name: 'Reset',
  mounted () {
    this.$router.go(-1) // no loitering
  }
}
</script>
