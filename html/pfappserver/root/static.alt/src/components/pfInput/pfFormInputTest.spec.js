import { factory } from '@/utils/test'
import Component from './pfFormInputTest'

describe('Component', () => {
  it('has scoped data', () => {
    expect(Component.data.constructor).toBe(Function)
  })
})

describe('Methods', () => {

  let wrapper, vm

  beforeEach(() => {
      wrapper = factory(Component)
      vm = wrapper.vm
  })

  afterEach(() => {
      wrapper.destroy()
  })

  it('has <button ref="button-test"/>', () => {
    // assert button-test ref exists
    expect(wrapper.findComponent({ ref: 'button-test' }).exists()).toBe(true)
  })

  it('when :value="" => disable button', async () => {
    wrapper.find('input[type="text"]').setValue('')
    await vm.$nextTick()

    // assert button is disabled when value is empty
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe('disabled')
  })

  it('when :value="defined" => enable button', async () => {
    wrapper.find('input[type="text"]').setValue('test')
    await vm.$nextTick()

    // assert button is enabled when value is not empty
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)
  })

  it('when :disabled="true" => disable button', async () => {
    wrapper.setProps({ disabled: true })
    await vm.$nextTick()

    // assert button is disabled when :disabled="true"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe('disabled')
  })

  it('when :disabled="false" => enable button', async () => {
    wrapper.find('input[type="text"]').setValue('test')
    wrapper.setProps({ disabled: false })
    await vm.$nextTick()

    // assert button is enabled when :value="defined" && :disabled="false"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)
  })

  it('when :readonly="true" => enable button', async () => {
    wrapper.find('input[type="text"]').setValue('test')
    wrapper.setProps({ readonly: false })
    await vm.$nextTick()

    // assert button is enabled when :value="defined" && :readonly="true"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe(undefined)
  })

  it('when :state="false" => disable button', async () => {
    wrapper.setProps({ state: false })
    await vm.$nextTick()

    // assert button is disabled when :state="false"
    expect(wrapper.findComponent({ ref: 'button-test' }).attributes('disabled')).toBe('disabled')
  })
})
