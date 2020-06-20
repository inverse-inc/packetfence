import { mount, shallowMount } from '@vue/test-utils'
import Component from './pfFormInput'
import {
  BFormInput
} from 'bootstrap-vue'

const factory = ({ propsData = {}, mocks = {}, stubs = {}, methods = {} } = {}) => {
  return mount(Component, { propsData, mocks, stubs, methods })
}

const shallowFactory = ({ propsData = {}, mocks = {}, stubs = {}, methods = {} } = {}) => {
  return shallowMount(Component, { propsData, mocks, stubs, methods })
}

describe('Component', () => {
  it('has no scoped data', () => {
    expect(Component.data).toBe(undefined)
  })
})

describe('Props', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory()
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('has <input ref="input">', () => {
    // assert input ref exists
    expect(wrapper.findAllComponents({ ref: 'input' }).exists()).toBe(true)
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

})

describe('Value', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory()
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


describe('Handlers', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = shallowFactory()
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
