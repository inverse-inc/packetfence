<template>
    <b-row class="justify-content-md-center mt-3">
        <b-col md="8" lg="6" xl="4">
          <transition name="fade" mode="out-in">

            RESET

          </transition>
        </b-col>
    </b-row>
</template>

<script>
export default {
  name: 'Reset',
  mounted () {
    this.$router.go(-1)
  }
}
</script>
