import { factory, shallowFactory } from '@/utils/test'
import Component from './pfFormInput'
import {
  BFormInput
} from 'bootstrap-vue'

describe('Component', () => {
  it('has no scoped data', () => {
    expect(Component.data).toBe(undefined)
  })
})

describe('Handlers', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = shallowFactory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('provides @focus handler', async () => {
    // assert method exists
    expect('focus' in vm).toBe(true)

    // assert method
    expect(vm.focus.constructor).toBe(Function)
  })

  it('provides @blur handler', async () => {
    // assert method exists
    expect('blur' in vm).toBe(true)

    // assert method
    expect(vm.blur.constructor).toBe(Function)
  })
})

describe('Props', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('has <input ref="input">', () => {
    // assert input ref exists
    expect(wrapper.findAllComponents({ ref: 'input' }).exists()).toBe(true)
  })

  it('propagates :disabled => <input disabled=":disabled">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('disabled')).toBe(false)

    wrapper.setProps({ disabled: true })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('disabled')).toBe(true)
  })

  it('when :disabled="false" => hide lock icon', async () => {
    wrapper.setProps({ disabled: false })
    await vm.$nextTick()

    // assert lock icon not exists
    expect(wrapper.findAllComponents({ ref: 'icon-lock' }).exists()).toBe(false)
  })

  it('when :disabled="true" => show lock icon', async () => {
    wrapper.setProps({ disabled: true })
    await vm.$nextTick()

    // assert lock icon exists
    expect(wrapper.findAllComponents({ ref: 'icon-lock' }).exists()).toBe(true)
  })

  it('propagates :readonly => <input readonly=":readonly">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('readonly')).toBe(false)

    wrapper.setProps({ readonly: true })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('readonly')).toBe(true)
  })

  it('when :readonly="false" => hide lock icon', async () => {
    wrapper.setProps({ readonly: false })
    await vm.$nextTick()

    // assert lock icon not exists
    expect(wrapper.findAllComponents({ ref: 'icon-lock' }).exists()).toBe(false)
  })

  it('when :readonly="true" => show lock icon', async () => {
    wrapper.setProps({ readonly: true })
    await vm.$nextTick()
    // assert lock icon exists
    expect(wrapper.findAllComponents({ ref: 'icon-lock' }).exists()).toBe(true)
  })

  it('propagates :placeholder => <input placeholder=":placeholder">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('placeholder')).toBe(null)

    wrapper.setProps({ placeholder: 'test' })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('placeholder')).toBe('test')
  })

  it('propagates :text => <form-text>{{text}}</form-text>', async () => {
    // assert default property
    expect(wrapper.findAllComponents({ ref: 'form-text' }).exists()).toBe(false)

    wrapper.setProps({ text: '<t data-test="">foo</b>' })
    await vm.$nextTick()

    // assert property exists in DOM
    expect(wrapper.find('t[data-test]').exists()).toBe(true)

    //assert property was mutated
    expect(wrapper.findComponent({ ref: 'form-text' }).html()).toContain('<t data-test="">foo</t>')
  })

  it('propagates :type => <input type=":type">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('type')).toBe('text')

    wrapper.setProps({ type: 'password' })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('type')).toBe('password')
  })

  it('propagates :columnLabel => <form-group label=":columnLabel">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'form-group' }).props('label')).toBe(undefined)

    wrapper.setProps({ columnLabel: 'test' })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'form-group' }).props('label')).toBe('test')
  })

  it('propagates :labelCols => <form-group label-cols=":labelCols">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'form-group' }).props('labelCols')).toBe(null)

    wrapper.setProps({ columnLabel: 'test' })
    await vm.$nextTick()
    // assert property was mutated, default labelCols = 3
    expect(wrapper.findComponent({ ref: 'form-group' }).props('labelCols')).toBe(3)

    wrapper.setProps({ labelCols: 12 })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'form-group' }).props('labelCols')).toBe(12)
  })
})

describe('State', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('propagates :invalid-feedback => <form-group invalid-feedback=":invalid-feedback">', async () => {
    wrapper.setProps({
      invalidFeedback: 'test',
      state: false
    })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.find('.is-invalid').exists()).toBe(true)
    expect(wrapper.find('.invalid-feedback').exists()).toBe(true)
    expect(wrapper.find('.invalid-feedback').html()).toContain('test')
  })

  it('propagates :state="true" => <form-group class="is-valid">', async () => {
    // assert default
    expect(wrapper.find('.is-valid').exists()).toBe(false)

    wrapper.setProps({
      invalidFeedback: 'test',
      state: true,
      stateMap: { true: null, false: null }
    })
    await vm.$nextTick()

    // assert property was not mutated
    expect(wrapper.find('.is-valid').exists()).toBe(false)

    wrapper.setProps({
      invalidFeedback: 'test',
      state: true,
      stateMap: { true: true, false: false }
    })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.find('.is-valid').exists()).toBe(true)
  })

  it('propagates :state="false" => <form-group class="is-invalid">', async () => {
    // assert default
    expect(wrapper.find('.is-invalid').exists()).toBe(false)

    wrapper.setProps({
      invalidFeedback: 'test',
      state: false
    })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.find('.is-invalid').exists()).toBe(true)
  })
})

describe('Slots', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component, {
        slots: {
          append: '<div data-test="append">foo</div>',
          prepend: '<div data-test="prepend">foo</div>'
        }
      })
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('propagates <slot name="prepend"></slot>', async () => {
    // assert method exists
    expect(wrapper.findAll('[data-test="prepend"]').length).toBe(1)

  })

  it('propagates <slot name="append"></slot>', async () => {
    // assert method exists
    expect(wrapper.findAll('[data-test="append"]').length).toBe(1)

  })
})

describe('Value', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('propagates :value => <input value=":value">', async () => {
    // assert default property
    expect(wrapper.findComponent({ ref: 'input' }).props('value')).toBe('')

    wrapper.setProps({ value: 'test' })
    await vm.$nextTick()

    // assert property was mutated
    expect(wrapper.findComponent({ ref: 'input' }).props('value')).toBe('test')
  })

  it('emits <input @input>', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().input).toBeFalsy()

    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().input).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().input.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().input[0]).toEqual(['test'])
  })

  it('emits <input @change>', async () => {
    // assert no event emitted after mount
    expect(wrapper.emitted().change).toBeFalsy()

    wrapper.find('input[type="text"]').setValue('test')
    wrapper.find('input[type="text"]').trigger('change')
    await vm.$nextTick()

    // assert event has been emitted
    expect(wrapper.emitted().change).toBeTruthy()

    // assert event count
    expect(wrapper.emitted().change.length).toBe(1)

    // assert event payload
    expect(wrapper.emitted().change[0]).toEqual(['test'])
  })
})
