<template>
    <b-container class="my-5">
        <b-row class="justify-content-md-center text-secondary">
            <b-col cols="12" md="auto">
                <icon v-if="isLoading" name="circle-notch" scale="1.5" spin></icon>
                <b-media v-else>
                    <template v-slot:aside><icon :name="icon" scale="2"></icon></template>
                    <h4><slot/></h4>
                    <p class="font-weight-light" v-if="text">{{ text }}</p>
                </b-media>
            </b-col>
        </b-row>
    </b-container>
</template>

<script>
import i18n from '@/utils/locale'

const props = {
    isLoading: {
      type: Boolean
    },
    text: {
      type: String,
      default: i18n.t('Please refine your search.')
    },
    icon: {
      type: String,
      default: 'search'
    }
}

// @vue/component
export default {
  name: 'base-table-empty',
  inheritAttrs: false,
  props
}
</script>
