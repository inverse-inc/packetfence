<template>
  <b-card no-body>
    <b-card-header>
      <h4 class="mb-0" v-t="'SSL Certificates'"></h4>
    </b-card-header>
    <!-- Loading progress indicator -->
    <b-container class="my-5" v-if="sortedCerts.length === 0">
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <icon name="circle-notch" scale="1.5" spin></icon>
        </b-col>
      </b-row>
    </b-container>
    <b-tabs v-model="tabIndex" card v-else>
      <b-tab v-for="id in sortedCerts" :key="id">
        <template slot="title">
          <icon scale=".5" :class="info[id].cert_key_match.success ? 'text-success' : 'text-danger'" name="circle"></icon>
          <icon scale=".5" :class="info[id].chain_is_valid.success ? 'text-success' : 'text-danger'" name="circle" class="fa-overlap mr-1" ></icon>
          {{ id.toUpperCase() }}
        </template>
        <!-- Edit mode -->
        <transition name="fade" mode="out-in">
          <b-form :key="'edit_' + id" @submit.prevent="save(id)" v-show="editMode[id]">
            <!-- Let's Encrypt -->
            <pf-form-range-toggle
              v-model="certs[id].lets_encrypt"
              :values="{ checked: 'enabled', unchecked: 'disabled' }"
              :column-label="$t('Use Let\'s Encrypt')"
              @input="toggleLetsEncrypt"
            ></pf-form-range-toggle>
            <pf-form-input :column-label="$t('Common Name')" ref="common_name" v-show="isEnabled(certs[id].lets_encrypt)"
              v-model="$v.certs[id].common_name.$model" :vuelidate="$v.certs[id].common_name" />
            <pf-form-row v-show="isEnabled(certs[id].lets_encrypt)">
              <b-form inline @submit.prevent="testLetsEncrypt(id)">
                <pf-button-save variant="outline-secondary" size="sm" :disabled="$v.certs[id].common_name.$invalid || isTestingLetsEncrypt" :isLoading="isTestingLetsEncrypt">{{ $t('Test public access') }}</pf-button-save>
                <span class="ml-3" :class="'text-' + letsEncryptState">{{ letsEncryptMsg }}</span>
              </b-form>
            </pf-form-row>
            <!-- Custom certificate -->
            <template v-if="!isEnabled(certs[id].lets_encrypt)">
              <pf-form-textarea rows="6" max-rows="6" :column-label="$t('Certificate')"
                v-model.trim="$v.certs[id].certificate.$model" :vuelidate="$v.certs[id].certificate"></pf-form-textarea>
              <pf-form-row row-class="mt-0 mb-3">
                <pf-form-upload class="btn-outline-secondary btn-sm" @load="certs[id].certificate = $event[0].result" :multiple="false" accept="text/*">
                  {{ $t('Choose Certificate') }}
                </pf-form-upload>
              </pf-form-row>
              <pf-form-textarea rows="6" max-rows="6" :column-label="$t('Certificate Authority')"
                v-model.trim="certs[id].ca" v-if="'ca' in certs[id]"></pf-form-textarea>
              <pf-form-row row-class="mt-0 mb-3">
                <pf-form-upload class="btn-outline-secondary btn-sm" @load="certs[id].ca = $event[0].result" :multiple="false" accept="text/*">
                  {{ $t('Choose Certificate Authority') }}
                </pf-form-upload>
              </pf-form-row>
              <pf-form-textarea rows="6" max-rows="6" :column-label="$t('Private Key')"
                v-model.trim="$v.certs[id].private_key.$model" :vuelidate="$v.certs[id].private_key"></pf-form-textarea>
              <pf-form-row row-class="mt-0 mb-3">
                <pf-form-upload class="btn-outline-secondary btn-sm" @load="certs[id].private_key = $event[0].result" :multiple="false" accept="text/*">
                  {{ $t('Choose Private Key') }}
                </pf-form-upload>
              </pf-form-row>
              <pf-form-range-toggle
                v-model="find_intermediate_cas"
                :column-label="$t('Find intermediate CA certificates automatically')"
              ></pf-form-range-toggle>
              <pf-form-fields
                v-if="!find_intermediate_cas"
                v-model="certs[id].intermediate_cas"
                :column-label="$t('Intermediate CA certificate(s)')"
                :button-label="$t('Add certificate')"
                :field="caCertificateField"
              ></pf-form-fields>
              <pf-form-row row-class="mt-0 mb-3">
                <pf-form-upload class="btn-outline-secondary btn-sm" @load="loadIntermediateCAs(certs[id], $event)" :multiple="true" accept="text/*">
                  {{ $t('Choose Intermediate CA certificate(s)') }}
                </pf-form-upload>
              </pf-form-row>
            </template>
            <b-form-row @mouseenter="$v.certs[id].$touch()">
              <pf-button-save :disabled="$v.certs[id].$invalid" :isLoading="isLoading" v-t="'Save'"></pf-button-save>
              <b-button v-t="'Cancel'" class="ml-1" variant="secondary" @click="editMode[id] = false"></b-button>
            </b-form-row>
          </b-form>
        </transition>
        <!-- View mode -->
        <transition name="fade" mode="out-in" appear>
          <b-form v-show="!editMode[id]">
            <b-form-group label-cols-md="3" label-size="lg" :label="$t('Certificate')">
              <b-container fluid>
                <b-row align-v="center" v-if="info[id].cert_key_match.success">
                  <b-col sm="3" class="col-form-label"><icon class="text-success" name="circle"></icon></b-col>
                  <b-col sm="9">{{ $t('Certificate/Key match')}}</b-col>
                </b-row>
                <b-row align-v="center" v-else>
                  <b-col sm="3" class="col-form-label"><icon class="text-danger fa-overlap" name="circle"></icon></b-col>
                  <b-col sm="9">{{ $t('Certificate/Key don\'t match')}}</b-col>
                </b-row>
                <b-row align-v="center" v-if="info[id].chain_is_valid.success">
                  <b-col sm="3" class="col-form-label"><icon class="text-success" name="circle"></icon></b-col>
                  <b-col sm="9">{{ $t('Chain is valid')}}</b-col>
                </b-row>
                <b-row align-v="center" v-else>
                  <b-col sm="3" class="col-form-label"><icon class="text-danger fa-overlap" name="circle"></icon></b-col>
                  <b-col sm="9">{{ $t('Chain is invalid')}}</b-col>
                </b-row>
                <pf-form-row align-v="baseline" v-for="(value, key) in info[id].certificate" :key="key" :column-label="$t(key)">
                  {{ value }}
                </pf-form-row>
              </b-container>
            </b-form-group>
            <b-form-group label-cols-md="3" label-size="lg" :label="$t('Certificate Authority')" v-if="info[id].ca">
              <b-container fluid>
                <pf-form-row align-v="baseline" v-for="(value, key) in info[id].ca" :key="key" :column-label="$t(key)">
                  {{ value }}
                </pf-form-row>
              </b-container>
            </b-form-group>
            <b-form-group label-cols-md="3" label-size="lg" v-for="(intermediate, index) in info[id].intermediate_cas" :key="intermediate">
              <template slot="label">{{ $t('Intermediate') }} <b-badge>{{ index + 1 }}</b-badge></template>
              <b-container fluid>
                <pf-form-row class="align-items-baseline" v-for="(value, key) in intermediate" :key="key" :column-label="$t(key)">
                  {{ value }}
                </pf-form-row>
              </b-container>
            </b-form-group>
            <b-form-row>
              <b-button v-t="'Edit'" @click="edit(id)"></b-button>
              <b-button v-t="'Generate Signing Request (CSR)'" size="sm" @click="toggleCSRModal" class="ml-1" variant="outline-secondary"></b-button>
            </b-form-row>
          </b-form>
        </transition>
      </b-tab>
    </b-tabs>
    <!-- Generate CSR modal -->
    <b-modal id="csrModal" size="lg" v-model="csrMode"
      @shown="csrModalShown"
      :ok-title="csr ? $t('Copy to clipboard') : $t('Generate')" @ok="generateCSR($event)"
      :ok-disabled="$v.csrForm.$invalid"
      :cancel-title="$t('Cancel')" @cancel="toggleCSRModal">
      <div slot="modal-title">
        <span v-html="csrModalTitle"></span>
      </div>
      <b-form @submit.prevent="generateCSR($event)" v-show="!csr">
        <pf-form-input :label-cols="6" :column-label="$t('2-letter country code')" ref="csr_country" v-model="$v.csrForm.country.$model" :vuelidate="$v.csrForm.country" />
        <pf-form-input :label-cols="6" :column-label="$t('State')" v-model="$v.csrForm.state.$model" :vuelidate="$v.csrForm.state" />
        <pf-form-input :label-cols="6" :column-label="$t('Locality')" v-model="$v.csrForm.locality.$model" :vuelidate="$v.csrForm.locality" />
        <pf-form-input :label-cols="6" :column-label="$t('Organization Name')" v-model="$v.csrForm.organization_name.$model" :vuelidate="$v.csrForm.organization_name" />
        <pf-form-input :label-cols="6" :column-label="$t('Common Name')" v-model="$v.csrForm.common_name.$model" :vuelidate="$v.csrForm.common_name" />
      </b-form>
      <b-form-textarea ref="csr" rows="6" max-rows="17" v-show="csr" v-model="csr"></b-form-textarea>
    </b-modal>
  </b-card>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfField from '@/components/pfField'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormRow from '@/components/pfFormRow'
import pfFormTextarea from '@/components/pfFormTextarea'
import pfFormUpload from '@/components/pfFormUpload'
const {
  minLength,
  required
} = require('vuelidate/lib/validators')
const { validationMixin } = require('vuelidate')

export default {
  name: 'certificates-view',
  mixins: [
    validationMixin
  ],
  components: {
    pfButtonSave,
    pfFormFields,
    pfFormInput,
    pfFormRangeToggle,
    pfFormRow,
    pfFormTextarea,
    pfFormUpload
  },
  props: {
    storeName: { // from router
      type: String,
      default: null,
      required: true
    },
    id: { // from router
      type: String,
      default: 'http'
    }
  },
  data () {
    return {
      info: {},
      certs: {},
      letsEncryptState: '',
      letsEncryptMsg: '',
      initCerts: ['http', 'radius'],
      sortedCerts: [],
      tabIndex: 0,
      editMode: {},
      csrMode: false,
      csrForm: {
        common_name: '',
        country: '',
        locality: '',
        organization_name: '',
        state: ''
      },
      csr: '',
      find_intermediate_cas: false,
      caCertificateField: {
        component: pfField,
        attrs: {
          field: {
            component: pfFormTextarea,
            attrs: { rows: 6 }
          }
        }
      }
    }
  },
  validations () {
    let v = {
      certs: {},
      csrForm: {
        common_name: { [this.$i18n.t('Required.')]: required },
        country: { [this.$i18n.t('Must be exactly two characters.')]: minLength(2) },
        locality: { [this.$i18n.t('Required.')]: required },
        organization_name: { [this.$i18n.t('Required.')]: required },
        state: { [this.$i18n.t('Required.')]: required }
      }
    }
    this.sortedCerts.reduce((v, cert) => {
      v[cert] = {
        common_name: {},
        certificate: {},
        private_key: {}
      }
      return v
    }, v.certs)
    this.sortedCerts.forEach((cert) => {
      if (this.isEnabled(this.certs[cert].lets_encrypt)) {
        v.certs[cert].common_name = { [this.$i18n.t('Required.')]: required }
      } else {
        v.certs[cert].certificate = { [this.$i18n.t('Required.')]: required }
        v.certs[cert].private_key = { [this.$i18n.t('Required.')]: required }
      }
    })
    return v
  },
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    },
    isTestingLetsEncrypt () {
      return this.$store.getters[`${this.storeName}/isTesting`]
    },
    csrModalTitle () {
      if (this.sortedCerts.length > this.tabIndex) {
        const name = this.sortedCerts[this.tabIndex].toUpperCase()
        return this.$i18n.t('Generate Signing Request for {certificate} certificate', { certificate: name })
      }
    }
  },
  methods: {
    isEnabled (value) {
      return value === 'enabled'
    },
    edit (id) {
      this.$store.dispatch(`${this.storeName}/getCertificate`, id).then(certificate => {
        const c = { ...{ common_name: '', lets_encrypt: 'disabled' }, ...certificate }
        this.$set(this.certs, id, c)
        this.$set(this.editMode, id, true)
      })
      window.scrollTo(0, 0)
    },
    toggleLetsEncrypt (value) {
      if (value === 'enabled') {
        this.$nextTick(() => {
          this.$refs.common_name[this.tabIndex].focus()
        })
      }
    },
    testLetsEncrypt (id) {
      this.$store.dispatch(`${this.storeName}/testLetsEncrypt`, this.certs[id].common_name).then(msg => {
        this.letsEncryptMsg = msg
        this.letsEncryptState = 'success'
      }).catch(err => {
        this.letsEncryptMsg = err
        this.letsEncryptState = 'danger'
      })
    },
    loadIntermediateCAs (cert, files) {
      cert.intermediate_cas = []
      files.forEach(file => {
        cert.intermediate_cas.push(file.result)
      })
    },
    save (id) {
      if (this.find_intermediate_cas) {
        delete this.certs[id].intermediate_cas
      }
      this.$store.dispatch(`${this.storeName}/createCertificate`, this.certs[id]).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('{certificate} certificate saved', { certificate: id.toUpperCase() }) })
      }).finally(() => window.scrollTo(0, 0))
    },
    toggleCSRModal () {
      this.csr = ''
      this.csrMode = !this.csrMode
    },
    csrModalShown () {
      this.$refs.csr_country.focus()
    },
    generateCSR ($event) {
      if (this.csr) {
        if (document.queryCommandSupported('copy')) {
          this.$refs.csr.$el.select()
          document.execCommand('copy')
          this.csr = ''
          this.$store.dispatch('notification/info', { message: this.$i18n.t('Signing Request copied to clipboard') })
        }
      } else {
        this.csrForm.id = this.sortedCerts[this.tabIndex]
        this.$store.dispatch(`${this.storeName}/generateCertificateSigningRequest`, this.csrForm).then(csr => {
          this.csr = csr
          this.$nextTick(() => this.$refs.csr.$el.select())
        })
        $event.preventDefault()
      }
    }
  },
  mounted () {
    Promise.all(
      this.initCerts.map(id => {
        return this.$store.dispatch(`${this.storeName}/getCertificateInfo`, id).then(info => {
          this.$set(this.certs, id, { letsencrypt: 'disabled', common_name: '', certificate: '', private_key: '' })
          this.$set(this.info, id, info)
        })
      })
    ).then(() => {
      this.sortedCerts = this.initCerts
    }).catch(() => {
      this.sortedCerts = []
    })
  }
}
</script>

<style lang="scss">
@import "../../../../node_modules/bootstrap/scss/functions";
@import "../../../styles/variables";
</style>
