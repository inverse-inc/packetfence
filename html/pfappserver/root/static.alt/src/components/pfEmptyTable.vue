<template>
    <b-container class="my-5">
        <b-row class="justify-content-md-center text-secondary">
            <b-col cols="12" md="auto">
                <icon v-if="isLoading" name="circle-notch" scale="1.5" spin></icon>
                <b-media v-else>
                    <template v-slot:aside><icon :name="icon" scale="2"></icon></template>
                    <h4><slot/></h4>
                    <p class="font-weight-light" v-if="subtext">{{ subtext }}</p>
                </b-media>
            </b-col>
        </b-row>
    </b-container>
</template>

<script>
export default {
  name: 'pf-empty-table',
  props: {
    isLoading: {
      type: Boolean,
      default: false
    },
    text: {
      type: String,
      default: null
    },
    icon: {
      type: String,
      default: 'search'
    }
  },
  computed: {
    subtext () {
      return this.text !== null ? this.text : this.$i18n.t('Please refine your search.')
    }
  }
}
</script>
