<template>
  <b-form-group>
    <b-form-row>
      <b-col><b-form-input v-model="options.pwlength" type="range" min="6" max="32"></b-form-input></b-col>
      <b-col>{{ $t('{count} characters', { count: options.pwlength }) }}</b-col>
    </b-form-row>
    <b-form-row>
      <b-col><b-form-checkbox v-model="options.upper">ABC</b-form-checkbox></b-col>
      <b-col><b-form-checkbox v-model="options.lower">abc</b-form-checkbox></b-col>
    </b-form-row>
    <b-form-row>
      <b-col><b-form-checkbox v-model="options.digits">123</b-form-checkbox></b-col>
      <b-col><b-form-checkbox v-model="options.special">!@#</b-form-checkbox></b-col>
    </b-form-row>
    <b-form-row>
      <b-col><b-form-checkbox v-model="options.brackets">({&lt;</b-form-checkbox></b-col>
      <b-col><b-form-checkbox v-model="options.high">äæ±</b-form-checkbox></b-col>
    </b-form-row>
    <b-form-row>
      <b-col><b-form-checkbox v-model="options.ambiguous">0Oo</b-form-checkbox></b-col>
    </b-form-row>
    <b-form-row>
      <b-col class="text-right">
        <b-button variant="primary" size="sm"
          @click="generate"
          @mouseover="$emit('mouseover', $event)"
          @mousemove="$emit('mousemove', $event)"
          @mouseout="$emit('mouseout', $event)"
        >{{ $t('Generate') }}</b-button>
      </b-col>
    </b-form-row>
  </b-form-group>
</template>

<script>
import password from '@/utils/password'

export default {
  name: 'pf-static-generate-password',
  data () {
    return {
      options: {
        pwlength: 8,
        upper: true,
        lower: true,
        digits: true,
        special: false,
        brackets: false,
        high: false,
        ambiguous: false
      }
    }
  },
  methods: {
    generate () {
      let p = password.generate(this.options)
      this.$emit('input', p)
    }
  }
}
</script>
