import Vue from 'vue'
import { validationMixin } from 'vuelidate'
import { required, minLength } from 'vuelidate/lib/validators'

export default {
  namespaced: true,
  state: () => {
    return {
      $form: {
        firstname: 'darren',
        lastname: 'satkunas',
        children: [
          {
            firstname: 'child1',
            lastname: 'satkunas'
          },
          {
            firstname: 'child2',
            lastname: 'satkunas'
          },
          {
            firstname: 'child3',
            lastname: 'satkunas'
          }
        ]
      },
      $validations: {
        $form: {
          firstname: {
            ['First name required.']: required,
            ['Minimum length 3 characters.']: minLength(3)
          },
          lastname: {
            ['Last name required.']: required,
            ['Minimum length 3 characters.']: minLength(3)
          },
          children: {
            $each: {
              firstname: {
                ['First name required.']: required,
                ['Minimum length 3 characters.']: minLength(3)
              },
              lastname: {
                ['Last name required.']: required,
                ['Minimum length 3 characters.']: minLength(3)
              }
            }
          }
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
    },
    $vNamespace: (state, getters) => (namespace, $v = getters.$validator.$v) => {
      while (namespace) { // handle namespace
        let [ first, ...remainder ] = namespace.split('.') // split namespace
        namespace = remainder.join('.')
        if (first in $v)
          $v = $v[first] // named property
        else if (!isNaN(+first))
          $v = $v.$each[first] // index property
        else
          return $v
      }
      return $v
    },
    $state: (state, getters) => (namespace) => {
      let $v = getters.$vNamespace(namespace)
      return !$v.$invalid
    },
    $feedback: (state, getters) => (namespace, separator = ' ') => {
      let $v = getters.$vNamespace(namespace)
      let feedback = []
      for (let validation of Object.keys($v.$params)) {
        if (!$v[validation]) feedback.push(validation)
      }
      return feedback.join(separator).trim()
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
