 <template>
  <b-card no-body>
    <b-card-header>
      <h4 class="d-inline mb-0" v-html="title.value"/>
      <base-button-help v-if="titleHelp"
        class="ml-1" :url="titleHelp" />
    </b-card-header>
    <b-form @submit.prevent="onSave" ref="rootRef">
      <the-form
        :form="form"
        :meta="meta"
        :isLoading="isLoading"
        v-bind="$props"
      />
    </b-form>
    <b-card-footer>
      <slot name="buttonsPrepend" v-if="$scopedSlots.buttonsPrepend" v-bind="scopedSlotProps" />
      <form-button-bar
        :isLoading="isLoading"
        :isSaveable="isSaveable"
        :isValid="isValid"
        :formRef="rootRef"
        @reset="onReset"
        @save="onSave"
      />
      <slot name="buttonsAppend" v-if="$scopedSlots.buttonsAppend" v-bind="scopedSlotProps" />
    </b-card-footer>
  </b-card>
</template>
<script>
import { BaseButtonHelp } from '@/components/new/'
import { useViewResourceProps as props } from '../../_composables/useViewResource'

// @vue/component
export default {
  name: 'base-view-resource',
  inheritAttrs: false,
  components: { // component stubs
    'form-button-bar': undefined,
    'the-form': undefined,
    BaseButtonHelp
  },
  props,
  setup: () => ({ // prop stubs
    rootRef: undefined,
    title: undefined,
    titleHelpUrl: undefined,
    form: undefined,
    meta: undefined,
    isLoading: undefined,
    isValid: undefined,
    actionKey: undefined,
    onReset: undefined,
    onSave: undefined,
    scopedSlotProps: {}
  })
}
</script>
