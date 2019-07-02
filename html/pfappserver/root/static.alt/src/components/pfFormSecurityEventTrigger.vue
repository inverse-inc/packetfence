<template>
  <b-form-row :id="'security-event-trigger-row_' + uuid"
    class="align-items-center security-event-trigger-row flex-nowrap text-center py-1"
    v-on="forwardListeners">
    <b-badge class="or">{{ $t('OR') }}</b-badge>
    <b-col cols="1" class="text-center col-form-label">
      <slot name="prepend"></slot>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="'endpoint_' + uuid">
        <span v-for="(desc, index) in forms.endpoint.description()" :key="desc">
          {{ desc }} <b-badge variant="light" v-if="forms.endpoint.description().length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-link>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="'profiling_' + uuid">
        <span v-for="(desc, index) in forms.profiling.description()" :key="desc">
          {{ desc }} <b-badge variant="light" v-if="forms.profiling.description().length - index > 1">{{ $t('AND') }}</b-badge>
        </span>
      </b-link>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="'usage_' + uuid">{{ forms.usage.description() }}</b-link>
    </b-col>
    <b-col>
      <b-badge>{{ $t('AND') }}</b-badge>
    </b-col>
    <b-col cols="2">
      <b-link href="javascript:void(0)" :disabled="disabled" :id="'event_' + uuid">{{ forms.event.description() }}</b-link>
    </b-col>
    <b-col cols="1" class="col-form-label">
      <slot name="append"></slot>
    </b-col>
    <!-- Popover for each category -->
    <b-popover v-for="category in Object.keys(forms)"
      triggers="click"
      placement="top"
      :key="category"
      :show.sync="popover[category]"
      :target="category + '_' + uuid"
      :container="'security-event-trigger-row_' + uuid">
      <div :ref="category + 'Popover'">
        <pf-config-view
          v-if="popover[category]"
          card-class="card-sm"
          :form="forms[category]"
          :model="triggerCopy[category]"
          :vuelidate="$v.triggerCopy[category]"
          @validations="triggerValidations[category] = $event"
          border-variant="light">
          <template slot="header" is="b-card-header"><h5 class="m-0" v-text="forms[category].title"></h5></template>
          <template slot="footer" is="b-card-footer" class="text-right" @mouseenter="$v.triggerCopy[category].$touch()">
            <pf-button size="sm" variant="outline-secondary" class="mr-1" @click="resetCategory(category)">{{ $t('Cancel') }}</pf-button>
            <pf-button size="sm" variant="danger" class="mr-1" v-if="forms[category].deletable" @click="removeCategory(category)">{{ $t('Delete') }}</pf-button>
            <pf-button-save size="sm" :disabled="invalidForm(category)" @click="updateCategory(category)">{{ $t('OK') }}</pf-button-save>
          </template>
        </pf-config-view>
      </div>
    </b-popover>
  </b-form-row>
</template>

<script>
import apiCall from '@/utils/api'
import bytes from '@/utils/bytes'
import i18n from '@/utils/locale'
import { pfFieldType as fieldType } from '@/globals/pfField'
import pfButton from '@/components/pfButton'
import pfButtonSave from '@/components/pfButtonSave'
import pfConfigView from '@/components/pfConfigView'
import pfFieldTypeValue from '@/components/pfFieldTypeValue'
import pfFormFields from '@/components/pfFormFields'
import pfFormInput from '@/components/pfFormInput'
import pfFormSelect from '@/components/pfFormSelect'
import pfFormPrefixMultiplier from '@/components/pfFormPrefixMultiplier'
import { pfConfigurationAttributesFromMeta } from '@/globals/configuration/pfConfiguration'
import { limitSiblingFields } from '@/globals/pfValidators'
const { validationMixin } = require('vuelidate')
const { required } = require('vuelidate/lib/validators')

/**
 * Triggers categories
 *
 * - Keys are used to populate `this.trigger`
 * - Values are used to build the descriptions
 */
const categoryOptions = {
  endpoint: {
    role: i18n.t('Role'),
    mac: i18n.t('MAC Address'),
    switch: i18n.t('Switch'),
    switch_group: i18n.t('Switch Group')
  },
  profiling: {
    device: i18n.t('Device'),
    dhcp_fingerprint: i18n.t('DHCP Fingerprint'),
    dhcp_vendor: i18n.t('DHCP Vendor'),
    dhcp6_fingerprint: i18n.t('DHCPv6 Fingerprint'),
    dhcp6_enterprise: i18n.t('DHCPv6 Enterprise'),
    mac_vendor: i18n.t('MAC Vendor'),
    useragent: i18n.t('User Agent')
  },
  usage: {
    accounting: i18n.t('Accounting')
  },
  event: {
    custom: i18n.t('Custom'),
    detect: i18n.t('Detect'),
    internal: i18n.t('Internal'),
    nessus: 'Nessus',
    nessus6: 'Nessus v6',
    openvas: 'OpenVAS',
    suricata_event: 'Suricata Event',
    suricata_md5: 'Suricata MD5',
    nexpose_event_contains: 'Nexpose event contains ..',
    nexpose_event_starts_with: 'Nexpose event starts with ..',
    provisioner: i18n.t('Provisioner')
  }
}

/**
 * Usage options
 */
const directionOptions = {
  TOT: i18n.t('Total'),
  IN: i18n.t('Inbound'),
  OUT: i18n.t('Outbound')
}
const intervalOptions = {
  D: i18n.t('Day'),
  W: i18n.t('Week'),
  M: i18n.t('Month'),
  Y: i18n.t('Year')
}

export default {
  name: 'pf-form-security-event-trigger',
  mixins: [
    validationMixin
  ],
  components: {
    pfButton,
    pfButtonSave,
    pfConfigView,
    pfFormInput
  },
  props: {
    value: {
      default: null
    },
    uuid: {
      default: null // from pfFormFields
    },
    meta: {
      type: Object,
      default: () => {}
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  data () {
    return {
      focus: false,
      trigger: { endpoint: { conditions: [] }, profiling: { conditions: [] }, usage: {}, event: {} },
      triggerCopy: {},
      triggerValidations: { endpoint: {}, profiling: {}, usage: {}, event: {} }, // will be overloaded with data from the pfConfigView
      popover: { endpoint: false, profiling: false, usage: false, event: false }

    }
  },
  computed: {
    forwardListeners () {
      const { input, ...listeners } = this.$listeners
      return listeners
    },
    forms () {
      return {
        /**
         * Endpoint trigger
         */
        endpoint: {
          description: () => {
            const conditions = this.trigger.endpoint.conditions.map(condition => {
              const { type, value } = condition
              return `${categoryOptions.endpoint[type]}: ${value}`
            })
            return conditions.length > 0 ? conditions : [this.$i18n.t('No condition')]
          },
          title: this.$i18n.t('Endpoint'),
          fields: [
            {
              tab: null, // ignore tabs
              fields: [
                {
                  fields: [
                    {
                      component: pfFormFields,
                      key: 'conditions',
                      attrs: {
                        buttonLabel: i18n.t('Add Condition'),
                        sortable: false,
                        field: {
                          component: pfFieldTypeValue,
                          attrs: {
                            typeLabel: this.$i18n.t('Select type'),
                            valueLabel: this.$i18n.t('Select value'),
                            fields: [
                              {
                                ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.role'),
                                ...{
                                  value: 'role',
                                  text: categoryOptions.endpoint.role,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              },
                              {
                                value: 'mac',
                                text: categoryOptions.endpoint.mac,
                                types: [fieldType.SUBSTRING],
                                validators: {
                                  value: {
                                    [this.$i18n.t('Value required.')]: required
                                  },
                                  type: {
                                    /* Don't allow elsewhere */
                                    [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                  }
                                }
                              },
                              {
                                ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.switch'),
                                ...{
                                  value: 'switch',
                                  text: categoryOptions.endpoint.switch,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              },
                              {
                                ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.switch_group'),
                                ...{
                                  value: 'switch_group',
                                  text: categoryOptions.endpoint.switch_group,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              }
                            ]
                          }
                        }
                      }
                    }
                  ]
                }
              ]
            }
          ]
        },
        /**
         * Profiling trigger
         */
        profiling: {
          description: () => {
            const conditions = this.trigger.profiling.conditions.map(condition => {
              const { type, value } = condition
              let name = value
              if (typeof value === 'object') {
                name = value.name
              }
              return `${categoryOptions.profiling[type]}: ${name}`
            })
            return conditions.length > 0 ? conditions : [this.$i18n.t('All device types')]
          },
          title: this.$i18n.t('Device Profiling'),
          fields: [
            {
              tab: null, // ignore tabs
              fields: [
                {
                  fields: [
                    {
                      component: pfFormFields,
                      key: 'conditions',
                      attrs: {
                        buttonLabel: i18n.t('Add Condition'),
                        sortable: false,
                        field: {
                          component: pfFieldTypeValue,
                          attrs: {
                            typeLabel: this.$i18n.t('Select type'),
                            valueLabel: this.$i18n.t('Select value'),
                            fields: [
                              {
                                attrs: {
                                  ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.device'),
                                  ...{ collapseObject: false }
                                },
                                ...{
                                  value: 'device',
                                  text: categoryOptions.profiling.device,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              },
                              {
                                attrs: {
                                  ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.dhcp_fingerprint'),
                                  ...{ collapseObject: false }
                                },
                                ...{
                                  value: 'dhcp_fingerprint',
                                  text: categoryOptions.profiling.dhcp_fingerprint,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              },
                              {
                                attrs: {
                                  ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.dhcp_vendor'),
                                  ...{ collapseObject: false }
                                },
                                ...{
                                  value: 'dhcp_vendor',
                                  text: categoryOptions.profiling.dhcp_vendor,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              },
                              {
                                attrs: {
                                  ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.dhcp6_fingerprint'),
                                  ...{ collapseObject: false }
                                },
                                ...{
                                  value: 'dhcp6_fingerprint',
                                  text: categoryOptions.profiling.dhcp6_fingerprint,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              },
                              {
                                attrs: {
                                  ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.dhcp6_enterprise'),
                                  ...{ collapseObject: false }
                                },
                                ...{
                                  value: 'dhcp6_enterprise',
                                  text: categoryOptions.profiling.dhcp6_enterprise,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              },
                              {
                                attrs: {
                                  ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.mac_vendor'),
                                  ...{ collapseObject: false }
                                },
                                ...{
                                  value: 'mac_vendor',
                                  text: categoryOptions.profiling.mac_vendor,
                                  types: [fieldType.OPTIONS],
                                  validators: {
                                    type: {
                                      /* Don't allow elsewhere */
                                      [this.$i18n.t('Duplicate condition.')]: limitSiblingFields('type', 0)
                                    }
                                  }
                                }
                              }
                            ]
                          }
                        }
                      }
                    }
                  ]
                }
              ]
            }
          ]
        },
        /**
         * Usage trigger
         */
        usage: {
          description: () => {
            const { direction, limit, interval } = this.trigger.usage
            return direction ? `${bytes.toHuman(limit, 0, true)}B ${directionOptions[direction]}/${intervalOptions[interval]}` : this.$i18n.t('Any data usage')
          },
          title: this.$i18n.t('Usage'),
          deletable: true,
          fields: [
            {
              tab: null, // ignore tabs
              fields: [
                {
                  fields: [
                    {
                      key: 'direction',
                      component: pfFormSelect,
                      attrs: {
                        columnLabel: this.$i18n.t('Direction'),
                        class: 'w-100 mb-1',
                        placeholder: this.$i18n.t('Select direction'),
                        options: Object.keys(directionOptions).map(key => ({ value: key, text: directionOptions[key] }))
                      },
                      validators: {
                        [this.$i18n.t('Value required.')]: required
                      }
                    },
                    {
                      key: 'limit',
                      component: pfFormPrefixMultiplier,
                      attrs: {
                        columnLabel: this.$i18n.t('Limit'),
                        class: 'w-100 mb-1'
                      },
                      validators: {
                        [this.$i18n.t('Value required.')]: required
                      }
                    },
                    {
                      key: 'interval',
                      component: pfFormSelect,
                      attrs: {
                        columnLabel: this.$i18n.t('Interval'),
                        class: 'w-100 mb-1',
                        placeholder: this.$i18n.t('Select interval'),
                        options: Object.keys(intervalOptions).map(key => ({ value: key, text: intervalOptions[key] }))
                      },
                      validators: {
                        [this.$i18n.t('Value required.')]: required
                      }
                    }
                  ]
                }
              ]
            }
          ]
        },
        /**
         * Event trigger
         */
        event: {
          description: () => {
            const { typeValue: { type, value } = {} } = this.trigger.event
            return type ? `${categoryOptions.event[type]}: ${value}` : this.$i18n.t('Any event')
          },
          title: this.$i18n.t('Event'),
          deletable: true,
          fields: [
            {
              tab: null, // ignore tabs
              fields: [
                {
                  fields: [
                    {
                      component: pfFieldTypeValue,
                      key: 'typeValue',
                      attrs: {
                        typeLabel: this.$i18n.t('Select trigger type'),
                        valueLabel: this.$i18n.t('Select trigger value'),
                        fields: [
                          {
                            value: 'custom',
                            text: categoryOptions.event.custom,
                            types: [fieldType.SUBSTRING],
                            validators: {
                              value: {
                                [this.$i18n.t('Value required.')]: required
                              }
                            }
                          },
                          {
                            value: 'detect',
                            text: categoryOptions.event.detect,
                            types: [fieldType.SUBSTRING],
                            validators: {
                              value: {
                                [this.$i18n.t('Value required.')]: required
                              }
                            }
                          },
                          {
                            ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.internal'),
                            ...{
                              value: 'internal',
                              text: categoryOptions.event.internal,
                              types: [fieldType.OPTIONS]
                            }
                          },
                          {
                            value: 'nessus',
                            text: categoryOptions.event.nessus,
                            types: [fieldType.SUBSTRING],
                            validators: {
                              value: {
                                [this.$i18n.t('Value required.')]: required
                              }
                            }
                          },
                          {
                            value: 'nessus6',
                            text: categoryOptions.event.nessus6,
                            types: [fieldType.SUBSTRING],
                            validators: {
                              value: {
                                [this.$i18n.t('Value required.')]: required
                              }
                            }
                          },
                          {
                            value: 'nexpose_event_contains',
                            text: categoryOptions.event.nexpose_event_contains,
                            types: [fieldType.SUBSTRING],
                            validators: {
                              value: {
                                [this.$i18n.t('Value required.')]: required
                              }
                            }
                          },
                          {
                            ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.nexpose_event_starts_with'),
                            ...{
                              value: 'nexpose_event_starts_with',
                              text: categoryOptions.event.nexpose_event_starts_with,
                              types: [fieldType.OPTIONS]
                            }
                          },
                          {
                            value: 'openvas',
                            text: categoryOptions.event.openvas,
                            types: [fieldType.SUBSTRING],
                            validators: {
                              value: {
                                [this.$i18n.t('Value required.')]: required
                              }
                            }
                          },
                          {
                            ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.provisioner'),
                            ...{
                              value: 'provisioner',
                              text: categoryOptions.event.provisioner,
                              types: [fieldType.OPTIONS]
                            }
                          },
                          {
                            ...pfConfigurationAttributesFromMeta(this.meta, 'triggers.suricata_event'),
                            ...{
                              value: 'suricata_event',
                              text: categoryOptions.event.suricata_event,
                              types: [fieldType.OPTIONS]
                            }
                          },
                          {
                            value: 'suricata_md5',
                            text: categoryOptions.event.suricata_md5,
                            types: [fieldType.SUBSTRING],
                            validators: {
                              value: {
                                [this.$i18n.t('Value required.')]: required
                              }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    },
    mouseDown () {
      return this.$store.getters['events/mouseDown']
    }
  },
  watch: {
    meta (newMeta) {
      /**
       * Expand dynamic values
       */
      for (const category of ['endpoint', 'profiling']) {
        this.trigger[category].conditions.forEach(condition => {
          let { type: field, value } = condition
          if (field && value) {
            let { [field]: { allowed_lookup: allowedLookup, type, item } = {} } = newMeta.triggers.item.properties
            if (type === 'array' && item) {
              const { allowed_lookup: itemAllowedLookup } = item
              if (itemAllowedLookup) {
                // value is an array
                value.forEach((query, index) => {
                  this.expandValue({ allowedLookup: itemAllowedLookup, trackBy: 'value', label: 'name' }, query).then(item => {
                    this.$set(value, index, item)
                    this.triggerCopy = JSON.parse(JSON.stringify(this.trigger))
                  })
                })
              }
            } else if (allowedLookup) {
              this.expandValue({ allowedLookup, trackBy: 'value', label: 'name' }, value).then(item => {
                condition.value = item
                this.triggerCopy = JSON.parse(JSON.stringify(this.trigger))
              })
            }
          }
        })
      }
    },
    mouseDown (pressed) {
      if (pressed) this.onBodyClick(this.$store.state.events.mouseEvent)
    }
  },
  methods: {
    init () {
      /**
       * Associate each condition to a category (endpoint/profiling/usage/event)
       */
      for (const field in this.value) {
        const value = this.value[field]
        if (value && value.length) {
          let category = null
          for (const key in categoryOptions) {
            if (Object.keys(categoryOptions[key]).includes(field)) {
              category = key
              break
            }
          }
          if (category) {
            let condition = { typeValue: { type: field, value: JSON.parse(JSON.stringify(value)) } }
            if ('conditions' in this.trigger[category]) {
              this.trigger[category].conditions.push(condition.typeValue)
            } else {
              this.trigger[category] = condition
            }
            if (category === 'usage') {
              // Decompose data usage
              const { groups } = value.match(/(?<direction>TOT|IN|OUT)(?<limit>[0-9]+)(?<multiplier>[KMG]?)B(?<interval>[DWMY])/)
              if (groups) {
                this.trigger[category].direction = groups.direction
                this.trigger[category].limit = groups.limit
                this.trigger[category].interval = groups.interval
                let multiplier
                switch (groups.multiplier) {
                  case 'K':
                    multiplier = 1
                    break
                  case 'M':
                    multiplier = 2
                    break
                  case 'G':
                    multiplier = 3
                    break
                  default:
                    multiplier = 0
                }
                this.trigger[category].limit *= Math.pow(1024, multiplier)
              }
            }
          } else {
            throw new Error(`Uncategorized field: ${field}`)
          }
        }
      }
      this.triggerCopy = JSON.parse(JSON.stringify(this.trigger))
    },
    expandValue (context, value) {
      const { allowedLookup: { field_name: fieldName, value_name: valueName, search_path: url }, trackBy, label } = context
      return apiCall.request({
        url,
        method: 'post',
        baseURL: '', // reset
        data: {
          query: { op: 'and', values: [{ op: 'and', values: [{ field: valueName, op: 'equals', value }] }] },
          fields: [fieldName, valueName],
          sort: [fieldName],
          cursor: 0,
          limit: 1
        }
      }).then(response => {
        const [item] = response.data.items
        return { [trackBy]: item[valueName], [label]: item[fieldName] }
      })
    },
    invalidForm (category) {
      return this.$v.triggerCopy[category].$invalid
    },
    updateCategory (category) {
      this.popover[category] = false
      this.trigger[category] = JSON.parse(JSON.stringify(this.triggerCopy[category]))
      if (category === 'usage') {
        Object.assign(this.trigger[category], {
          typeValue: {
            type: 'accounting',
            value: this.trigger[category].direction +
              bytes.toHuman(this.trigger[category].limit, 0, true).replace(/ /, '').toUpperCase() + 'B' +
              this.trigger[category].interval
          }
        })
      }
      let { conditions, typeValue } = this.trigger[category]
      if (typeValue) {
        conditions = [typeValue]
      }
      // Assign new values to model
      if (this.value) {
        Object.keys(categoryOptions[category]).forEach(field => delete this.value[field])
      }
      conditions.forEach(condition => {
        let { type: field, value } = condition
        let newValue = value
        if (field && value) {
          // Collapse object
          let { [field]: { allowed_lookup: allowedLookup, type, item } = {} } = this.meta.triggers.item.properties
          if (type === 'array' && item) {
            const { allowed_lookup: itemAllowedLookup } = item
            if (itemAllowedLookup) {
              // value is an array
              let values = []
              value.forEach((expandedValue, index) => {
                values[index] = expandedValue.value
              })
              newValue = values
            }
          } else if (allowedLookup) {
            newValue = value.value
          }
        }
        // Update model
        if (!this.value) this.value = {}
        this.value[field] = newValue
      })
      this.$emit('input', this.value)
    },
    resetCategory (category) {
      // eslint-disable-next-line
      console.debug(`reset category ${category}`)
      this.popover[category] = false
      this.triggerCopy[category] = JSON.parse(JSON.stringify(this.trigger[category]))
    },
    removeCategory (category) {
      this.popover[category] = false
      this.trigger[category] = {}
    },
    onBodyClick ($event) {
      if (Object.values(this.popover).includes(true)) {
        // At least one popover is opened
        const isInsidePopover = Object.keys(this.forms).find(category => {
          const refs = this.$refs[category + 'Popover']
          return refs && refs.length > 0 && refs[0].contains($event.target)
        })
        if (isInsidePopover === undefined) {
          // Click is outside popover -- close all popover
          const { id = '', parentNode: { id: parentId } } = $event.target
          for (const category in this.popover) {
            // Ignore clicks on popover links
            if (![id, parentId].includes([category, this.uuid].join('_'))) {
              if (this.popover[category]) {
                // Cancel modifications
                this.resetCategory(category)
              }
            }
          }
        }
      }
    }
  },
  validations () {
    return {
      triggerCopy: this.triggerValidations
    }
  },
  created () {
    this.init()
  }
}
</script>

<style lang="scss">
/**
 * Position the "or" badge bellow each trigger except the last one
 */
.security-event-trigger-row {
  position: relative;
  .or {
    position: absolute;
    bottom: -1em;
    left: 5em;
  }
}
.pf-form-field-component-container:last-child .or {
  display: none;
}

/**
 * Make popover larger
 */
.popover {
  max-width: $popover-max-width * 2;
}

/**
 * No padding inside popover
 */
.security-event-trigger-row .popover,
.security-event-trigger-row .input-group {
  width: 100%;
}
.security-event-trigger-row .popover-body {
  padding: 0;
}
</style>
