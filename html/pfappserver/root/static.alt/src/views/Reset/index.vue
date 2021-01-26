<template>
  <div class="container-fluid position-fixed mt-3" style="top:50%;">
    <b-row class="justify-content-md-center text-secondary">
      <b-col cols="12" md="auto">
        <b-media no-body>
          <template v-slot:aside><icon name="circle-notch" scale="2" spin></icon></template>
          <div class="mx-2">
            <h4 v-t="'Resetting View...'"></h4>
          </div>
        </b-media>
      </b-col>
    </b-row>
  </div>
</template>

<script>
export default {
  name: 'Reset',
  mounted () {
    this.$router.go(-1) // no loitering
  }
}
</script>
