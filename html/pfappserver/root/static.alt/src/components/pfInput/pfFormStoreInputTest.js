import pfFormInputTest from './pfFormInputTest'
import mixinSass from './mixin.scss' // use a mixin to import sass
import mixinFormStore from '@/components/_mixins/formStore'

// @vue/component
export default {
  name: 'pf-form-store-input-test',
  extends: pfFormInputTest,
  mixins: [
    mixinFormStore, // uses formStore (overrides _mixins/formModel)
    mixinSass
  ]
}
