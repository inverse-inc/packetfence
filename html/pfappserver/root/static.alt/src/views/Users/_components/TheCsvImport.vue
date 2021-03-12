<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'Import Users'"></h4>
    </b-card-header>
    <div class="card-body p-0">
      <b-tabs ref="tabs" v-model="tabIndex" card pills>
        <b-tab v-for="(file, index) in files" :key="file.name + file.lastModified"
          :title="file.name" :title-link-class="(tabIndex === index) ? ['bg-primary', 'text-light'] : ['bg-light', 'text-primary']"
          no-body
        >
          <template v-slot:title>
            <b-button-close class="ml-2" :class="(tabIndex === index) ? 'text-white' : 'text-primary'" @click.stop.prevent="closeFile(index)" v-b-tooltip.hover.left.d300 :title="$t('Close File')">
              <icon name="times" class="align-top ml-1"></icon>
            </b-button-close>
            {{ file.name }}
          </template>
          <base-csv-import :ref="'import-' + index"
            :file="file"
            :fields="importFields"
            :is-loading="isLoading"
            :import-promise="importPromise"
            hover
            striped
          >
            <b-card no-body>
              <b-card-header>
                <h4 v-t="'Additional User Options'"></h4>
                <p class="mb-0" v-t="'Complete the following additional static fields.'"></p>
              </b-card-header>
              <div class="card-body">
                <base-form
                  :form="form"
                  :schema="schema"
                  :isLoading="isLoading"
                  class="pt-0"
                >
                  <base-form-group
                    :column-label="$t('Registration Window')"
                  >
                    <input-group-valid-from namespace="valid_from"
                      class="flex-grow-1" />
                    <b-button variant="link" disabled><icon name="long-arrow-alt-right"></icon></b-button>
                    <input-group-expiration namespace="expiration"
                      class="flex-grow-1" />
                  </base-form-group>
                  <form-group-actions namespace="actions"
                    :column-label="$t('Actions')"
                  />
                </base-form>
                <form-group-password-options v-model="passwordOptions"
                  :column-label="$t('Password Options')"
                  :text="$t('When no password is imported, a random password is generated using this criteria.')"
                  :disabled="isLoading"
                />
              </div>
            </b-card>
          </base-csv-import>
        </b-tab>
        <template v-slot:tabs-end>
          <pf-form-upload @files="files = $event" @focus="tabIndex = $event" :multiple="true" :cumulative="true" accept="text/*, .csv">{{ $t('Open CSV File') }}</pf-form-upload>
        </template>
        <template v-slot:empty>
          <div class="text-center text-muted">
            <b-container class="my-5">
              <b-row class="justify-content-md-center text-secondary">
                  <b-col cols="12" md="auto">
                    <icon v-if="isLoading" name="sync" scale="2" spin></icon>
                    <b-media v-else>
                      <template v-slot:aside><icon name="file" scale="2"></icon></template>
                      <h4>{{ $t('There are no open CSV files') }}</h4>
                    </b-media>
                  </b-col>
              </b-row>
            </b-container>
          </div>
        </template>
      </b-tabs>
    </div>
    <users-preview-modal v-model="showUsersPreviewModal" store-name="$_users" />
  </b-card>
</template>

<script>
import {
  BaseCsvImport,
  BaseForm,
  BaseFormGroup
} from '@/components/new/'
import {
  InputGroupValidFrom,
  InputGroupExpiration,
  FormGroupActions,
  FormGroupPasswordOptions
} from './'
import pfFormUpload from '@/components/pfFormUpload'
import UsersPreviewModal from './UsersPreviewModal'

const components = {
  BaseCsvImport,
  BaseForm,
  BaseFormGroup,
  InputGroupValidFrom,
  InputGroupExpiration,
  FormGroupActions,
  FormGroupPasswordOptions,

  UsersPreviewModal,
  pfFormUpload
}

import { computed, provide, ref } from '@vue/composition-api'
import { MysqlDatabase } from '@/globals/mysql'
import { pfActions } from '@/globals/pfActions'
import password from '@/utils/password'
import {
  importFields,
  importForm as defaults,
  passwordOptions as _passwordOptions
} from '../_config/'
import { csv as schemaFn } from '../schema'

const setup = (props, context) => {
  
  const { root: { $store } = {} } = context
  
  const files = ref([])
  const form = ref({ ...defaults }) // dereferenced
  const schema = computed(() => schemaFn(props, form.value))
  const passwordOptions = ref(_passwordOptions)
  const tabIndex = ref(0)
  
  const domainName = computed(() => {
    const { domain_name = null } = $store.getters['session/tenantMask'] || {}
    return domain_name
  })
    
  const onCloseFile = (index) => {
    const { [index]: { file } = {} } = files.value
    file.close()
    files.value.splice(index, 1)    
  }
  
  const isLoading = ref(false)
  const createdUsers = ref({})
  const showUsersPreviewModal = ref(false)
  const importPromise = (payload, dryRun, done) => {
    isLoading.value = true
    return new Promise((resolve, reject) => {
      if ('items' in payload) {
        payload.items = payload.items.map(item => { // glue payload together with local slot
          let merged = { ...item, ...form.value }
          const { category_id, actions = [] } = merged
          if (category_id) {
            delete merged.category_id
            merged.actions = [
              ...actions.filter(({ type }) => type !== 'set_role'),
              { type: 'set_role', value: category_id }
            ]
          }
          if (!('password' in merged)) // generate a unique password
            merged.password = password.generate(passwordOptions.value)
          if (domainName.value) // append domainName to pid when available (tenant)
            merged.pid = `${merged.pid}@${this.domainName}`
          return merged
        })
      }
      $store.dispatch('$_users/bulkImport', payload).then(result => {
        // do something with the result, then Promise.resolve to continue processing
        if (!dryRun) {
          createdUsers.value = result.reduce((_createdUsers, result) => {
            const { item } = result
            if ('pid' in item) {
              _createdUsers[item.pid] = (item.pid in _createdUsers)
                ? { ..._createdUsers[item.pid], ...item }
                : item
            }
            return _createdUsers
          }, createdUsers.value)
          if (done) { // processing is done
            if (Object.values(createdUsers.value).length > 0) {
              $store.commit('$_users/CREATED_USERS_REPLACED', Object.values(createdUsers.value))
              showUsersPreviewModal.value = true
            }
          }
        }
        resolve(result)
      }).catch(err => {
        // do something with the error, then Promise.reject to stop processing
        reject(err)
      }).finally(() => {
        isLoading.value = false
      })
    })
  }
  
  // provide actions to child components
  const actions = ref([])
  provide('actions', actions) // for FormGroupActions
  $store.dispatch('session/getAllowedUserActions').then(allowedActions => {
    actions.value = allowedActions.map(({action}) => {
      switch (action) {
        case 'set_access_duration':
        case 'set_access_level':
        case 'set_role':
        case 'set_unreg_date':
          return pfActions[`${action}_by_acl_user`] // remap action to user ACL
          // break
        default:
          return pfActions[action] // passthrough
      }
    })
  })
    
  return {
    importFields,
    MysqlDatabase,

    files,
    tabIndex,
    form,
    schema,
    passwordOptions,
    
    domainName,
    onCloseFile,
    isLoading,
    createdUsers,
    showUsersPreviewModal,
    importPromise
  }  
}

// @vue/component
export default {
  name: 'the-csv-import',
  inheritAttrs: false,
  components,
  setup
}
</script>
