import Vue from 'vue'
import { validationMixin } from 'vuelidate'
import { required, minLength } from 'vuelidate/lib/validators'

export default {
  namespaced: true,
  state: () => {
    return {
      $form: {
        firstname: 'darren',
        lastname: 'satkunas'
      },
      $validations: {
        $form: {
          firstname: { required, minLength: minLength(3) },
          lastname: { required, minLength: minLength(3) }
        }
      },
    }
  },
  getters: { // { state, getters, rootState, rootGetters }
    $form: (state) => state.$form,
    $validations: (state) => state.$validations,
    $validator: (state, getters) => { // vuelidate sandbox
      return new Vue({
        mixins: [ validationMixin ],
        computed: {
          $form () { return state.$form }
        },
        validations () { return state.$validations }
      })
    },
    $v: (state, getters) => {
      return Object.assign({}, getters.$validator.$v)
    }
  },
  actions: { // { state, rootState, commit, dispatch, getters, rootGetters }
    $touch: ({ getters }) => {
      getters.$validator.$v.$touch()
    }
  },
  mutations: { // state
  }
}
