import Vue from 'vue'
import { validationMixin } from 'vuelidate'
import { types } from '@/store'

export default {
  namespaced: true,
  state: () => {
    return {
      $form: {},
      $formStatus: '',
      $formMessage: '',

      $validations: {
        $form: {}
      },
      $validationsStatus: '',
      $validationsMessage: ''
    }
  },
  getters: { // { state, getters, rootState, rootGetters }
    isLoading: (state, getters) => getters.$formLoading || getters.$validationsLoading,
    $form: (state) => state.$form,
    $formLoading: (state) => state.$formStatus === types.LOADING,
    $formMessage: (state) => state.$formMessage,
    $formStatus: (state) => state.$formStatus,
    $formAnyError: (state, getters) => getters.$vuelidate.$anyError,
    $formAnyDirty: (state, getters) => getters.$vuelidate.$anyDirty,
    $formDirty: (state, getters) => getters.$vuelidate.$dirty,
    $formError: (state, getters) => getters.$vuelidate.$error,
    $formInvalid: (state, getters) => getters.$vuelidate.$invalid,
    $formPending: (state, getters) => getters.$vuelidate.$pending,
    $formNS: (state, getters) => (namespace, $form = getters.$form) => {
      while (namespace) { // handle namespace
        if (!$form) break
        let [ first, ...remainder ] = namespace.match(/([^\.|^\][]+)/g) // split namespace
        namespace = remainder.join('.')
        if (first in $form)
          $form = $form[first]
        else
          break
      }
      return $form || {}
    },
    $validations: (state) => state.$validations,
    $validationsLoading: (state) => state.$validationsStatus === types.LOADING,
    $validator: (state) => { // vuelidate sandbox
      return new Vue({
        mixins: [ validationMixin ],
        computed: {
          $form () { return state.$form }
        },
        validations () {
          return state.$validations
        }
      })
    },
    $vuelidate: (state, getters) => {
      return Object.assign({}, getters.$validator.$v.$form)
    },
    $vuelidateNS: (state, getters) => (namespace, $v = getters.$validator.$v.$form) => {
      while (namespace) { // handle namespace
        if (!$v) break
        let [ first, ...remainder ] = namespace.match(/([^\.|^\][]+)/g) // split namespace
        namespace = remainder.join('.')
        if (first in $v)
          $v = $v[first] // named property
        else if (!isNaN(+first))
          $v = $v.$each[first] // index property
        else
          break
      }
      return $v || {}
    },
    $stateNS: (state, getters) => (namespace) => {
      const { $invalid = false, $dirty = false, $anyDirty = false, $error = false, $anyError = false, $pending = false } = getters.$vuelidateNS(namespace)
      return { $invalid, $dirty, $anyDirty, $error, $anyError, $pending }
    },
    $feedbackNS: (state, getters) => (namespace, separator = ' ') => {
      let $v = getters.$vuelidateNS(namespace)
      let feedback = []
      if ('$params' in $v) {
        for (let validation of Object.keys($v.$params)) {
          if (!$v[validation]) feedback.push(validation)
        }
      }
      return feedback.join(separator).trim()
    },
    $vModel: (state, getters) => {
      /**
      * Proxy - helper to avoid exception when accessing an undefined property.
      * Allows a component template to reference a state - or a part of a state - that does not yet exist.
      */
      return new Proxy(state.$form, {
        has: (target, namespace) => true, // always satisfy
        get: (target, namespace) => {
          while (namespace) { // handle namespace
            let [ first, ...remainder ] = namespace.match(/([^\.|^\][]+)/g) // split namespace
            namespace = remainder.join('.')
            if (!(first in target)) { // not defined
              Vue.set(target, first, (remainder.length === 0) ? undefined : {}) // make reactive
            }
            target = target[first]
          }
          return target
        },
        set: (target, namespace, value) => {
          while (namespace) { // handle namespace
            let [ first, ...remainder ] = namespace.match(/([^\.|^\][]+)/g) // split namespace
            namespace = remainder.join('.')
            if (target && (first in target || !isNaN(+first))) {
              if (namespace) {
                target = target[first] // named property
              } else {
                Vue.set(target, first, value)
                return true
              }
            } else {
              return false
            }
          }
          target = value
          return true
        }
      })
    }
  },
  actions: { // { state, rootState, commit, dispatch, getters, rootGetters }
    $touch: ({ getters }) => {
      getters.$validator.$v.$touch()
    },
    setForm: ({ state, commit }, form) => {
      commit('SET_FORM_REQUEST')
      return new Promise((resolve, reject) => {
        Promise.resolve(form).then(form => {
          commit('SET_FORM_SUCCESS', form)
          resolve(state.$form)
        }).catch(err => {
          commit('SET_FORM_ERROR', err)
          reject(err)
        })
      })
    },
    setFormValidations: ({ state, commit, dispatch }, validations) => {
      commit('SET_FORM_VALIDATIONS_REQUEST')
      return new Promise((resolve, reject) => {
        Promise.resolve(validations).then(validations => {
          commit('SET_FORM_VALIDATIONS_SUCCESS', validations)
          resolve(state.$validations)
        }).catch(err => {
          commit('SET_FORM_VALIDATIONS_ERROR', err)
          reject(err)
        })
      })
    }
  },
  mutations: { // state
    SET_FORM_REQUEST: (state) => {
      state.$formStatus = types.LOADING
    },
    SET_FORM_ERROR: (state, data) => {
      state.$formStatus = types.ERROR
      const { response: { data: { message = '' } = {} } = {} } = data
      state.$formMessage = message
    },
    SET_FORM_SUCCESS: (state, form) => {
      state.$form = Object.assign({}, form) // dereference to avoid mutations
      state.$formStatus = types.SUCCESS
      state.$formMessage = ''
    },
    SET_FORM_VALIDATIONS_REQUEST: (state) => {
      state.$validationsStatus = types.LOADING
    },
    SET_FORM_VALIDATIONS_ERROR: (state, data) => {
      state.$validationsStatus = types.ERROR
      const { response: { data: { message = '' } = {} } = {} } = data
      state.$validationsMessage = message
    },
    SET_FORM_VALIDATIONS_SUCCESS: (state, validations) => {
      state.$validations.$form = validations
      state.$validationsStatus = types.SUCCESS
      state.$validationsMessage = ''
    }
  }
}
