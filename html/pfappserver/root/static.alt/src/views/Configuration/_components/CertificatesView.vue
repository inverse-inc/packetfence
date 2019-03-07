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
        <!-- View mode -->
        <b-form v-if="!editMode[id]">
          <b-form-group label-cols-md="3" label-size="lg" horizontal :label="$t('Certificate')">
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
          <b-form-group label-cols-md="3" label-size="lg" horizontal :label="$t('Certificate Authority')" v-if="info[id].ca">
            <b-container fluid>
              <pf-form-row align-v="baseline" v-for="(value, key) in info[id].ca" :key="key" :column-label="$t(key)">
                {{ value }}
              </pf-form-row>
            </b-container>
          </b-form-group>
          <b-form-group label-cols-md="3" label-size="lg" horizontal v-for="(intermediate, index) in info[id].intermediate_cas" :key="intermediate">
            <template slot="label">{{ $t('Intermediate') }} <b-badge>{{ index + 1 }}</b-badge></template>
            <b-container fluid>
              <pf-form-row class="align-items-baseline" v-for="(value, key) in intermediate" :key="key" :column-label="$t(key)">
                {{ value }}
              </pf-form-row>
            </b-container>
          </b-form-group>
          <b-form-row>
            <b-button v-t="'Edit'" @click="edit(id)"></b-button>
            <b-button v-t="'Generate Signing Request'" class="ml-1" variant="outline-secondary"></b-button>
          </b-form-row>
        </b-form>
        <!-- Edit mode -->
        <b-form @submit.prevent="save(id)" v-else-if="editMode[id]">
          <pf-form-range-toggle
            v-model="use_letsencrypt"
            :column-label="$t('Use Let\'s Encrypt')"
          ></pf-form-range-toggle>
          <pf-form-textarea rows="6" max-rows="6" :column-label="$t('Certificate')" v-model="certs[id].certificate"></pf-form-textarea>
          <pf-form-textarea rows="6" max-rows="6" :column-label="$t('Certificate Authority')" v-model="certs[id].ca" v-if="'ca' in certs[id]"></pf-form-textarea>
          <pf-form-textarea rows="6" max-rows="6" :column-label="$t('Private Key')" v-model="certs[id].private_key"></pf-form-textarea>
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
          <b-form-row>
            <pf-button-save :disabled="invalidForm" :isLoading="isLoading" v-t="'Save'"></pf-button-save>
            <b-button v-t="'Cancel'" class="ml-1" variant="secondary" @click="editMode[id] = false"></b-button>
          </b-form-row>
        </b-form>
      </b-tab>
    </b-tabs>
  </b-card>
</template>

<script>
import pfButtonSave from '@/components/pfButtonSave'
import pfField from '@/components/pfField'
import pfFormFields from '@/components/pfFormFields'
import pfFormRangeToggle from '@/components/pfFormRangeToggle'
import pfFormRow from '@/components/pfFormRow'
import pfFormTextarea from '@/components/pfFormTextarea'

export default {
  name: 'certificates-view',
  components: {
    pfButtonSave,
    pfFormFields,
    pfFormRangeToggle,
    pfFormRow,
    pfFormTextarea
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
      initCerts: ['http', 'radius'],
      sortedCerts: [],
      tabIndex: 0,
      editMode: {},
      use_letsencrypt: false,
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
  computed: {
    isLoading () {
      return this.$store.getters[`${this.storeName}/isLoading`]
    }
  },
  methods: {
    edit (id) {
      this.$store.dispatch(`${this.storeName}/getCertificate`, id).then(certificate => {
        this.$set(this.certs, id, certificate)
        this.$set(this.editMode, id, true)
      })
      window.scrollTo(0, 0)
    },
    save (id) {
      this.$store.dispatch(`${this.storeName}/createCertificate`, this.certs[id]).then(() => {
        this.$store.dispatch('notification/info', { message: this.$i18n.t('{certificate} certificate saved', { certificate: id.toUpperCase() }) })
      }).finally(() => window.scrollTo(0, 0))
    }
  },
  mounted () {
    Promise.all(
      this.initCerts.map(id => {
        return this.$store.dispatch(`${this.storeName}/getCertificateInfo`, id).then(info => {
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
