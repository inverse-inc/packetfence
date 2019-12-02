import Vue from 'vue'
import { validationMixin } from 'vuelidate'
import { types } from '@/store'

/**
 * Helper to proxy a deeply nested object that does not throw an exception when accessing an undefined property.
 * Allows a component template to reference a state - or a part of a state - that does not yet exist.
 *
 * @param {Object} obj - any object you wish to safely proxy.
 * @return {Object} a safe object where any non-existent key can be referenced without generating an exception.
 */
const safe = (obj) => {
  obj = (obj && obj.constructor === Object) ? obj : {}
  return new Proxy(obj, {
    get: (target, property, receiver) => {
      if (property === 'toJSON') return () => target
      if (property === Symbol.toPrimitive) return () => ''
      return (property in target && target[property])
        ? (target[property].constructor === Object)
          ? safe(Reflect.get(target, property, receiver))
          : Reflect.get(target, property, receiver)
        : safe()
    }
  })
}

export default {
  namespaced: true,
  state: () => {
    return {

      $form: false,
      $formStatus: '',
      $formMessage: '',

      $validations: false,
      $validationsStatus: '',
      $validationsMessage: ''
    }
  },
  getters: { // { state, getters, rootState, rootGetters }
    isLoading: (state, getters) => getters.$formLoading || getters.$validationsLoading,
    $form: (state) => {
console.log('get $form')
      return safe(state.$form)
    },
    $formLoading: (state) => state.$formStatus === types.LOADING,
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
    setValidations: ({ state, commit, dispatch }, validations) => {
      commit('SET_VALIDATIONS_REQUEST')
      return new Promise((resolve, reject) => {
        Promise.resolve(validations).then(validations => {
          commit('SET_VALIDATIONS_SUCCESS', validations)
          resolve(state.$validations)
        }).catch(err => {
          commit('SET_VALIDATIONS_ERROR', err)
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
      state.$form = form
      state.$formStatus = types.SUCCESS
      state.$formMessage = ''
    },
    SET_VALIDATIONS_REQUEST: (state) => {
      state.$validationsStatus = types.LOADING
    },
    SET_VALIDATIONS_ERROR: (state, data) => {
      state.$validationsStatus = types.ERROR
      const { response: { data: { message = '' } = {} } = {} } = data
      state.$validationsMessage = message
    },
    SET_VALIDATIONS_SUCCESS: (state, validations) => {
      state.$validations = validations
      state.$validationsStatus = types.SUCCESS
      state.$validationsMessage = ''
    }
  }
}
