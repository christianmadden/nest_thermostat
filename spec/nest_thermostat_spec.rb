require 'spec_helper'

module NestThermostat

  describe Nest do
    before(:all) do
      @nest = Nest.new(email: ENV['NEST_EMAIL'], password: ENV['NEST_PASSWORD'], temperature_scale: :fahrenheit)
    end

    it "logs in to home.nest.com" do
      expect(@nest.transport_url).to match(/transport\.(home\.)?nest\.com/)
    end

    it "detects invalid logins" do
      expect {
        Nest.new({email: 'invalid@example.com', password: 'asdf'})
      }.to raise_error
    end

    it "does not remember the login email or password" do
      nest = Nest.new(email: ENV['NEST_EMAIL'], password: ENV['NEST_PASSWORD'], temperature_scale: :fahrenheit)
      expect(nest).not_to respond_to(:email)
      expect(nest).not_to respond_to(:password)
    end

    it "gets structures" do
      expect(@nest.structures).to_not be_nil
    end

    it "sets a structure by name" do
      @nest.set_structure(ENV['NEST_STRUCTURE_NAME'])
      expect(@nest.structure['name']).to match ENV['NEST_STRUCTURE_NAME']
    end

    it "sets a default structure" do
      @nest.set_default_structure
      expect(@nest.structure['name']).to match ENV['NEST_STRUCTURE_NAME']
    end

    it "gets the temperature before setting a device" do
      expect {
        @nest.current_temperature
      }.to raise_error
    end

    it "gets devices" do
      expect(@nest.devices).to_not be_nil
    end

    it "sets a device by name" do
      @nest.set_device(ENV['NEST_DEVICE_NAME'])
      expect(@nest.device()['serial_number']).to match ENV['NEST_DEVICE_SERIAL_NUMBER']
    end

    it "sets a default device" do
      @nest.set_default_device
      expect(@nest.device()['serial_number']).to_not be_nil
    end

    it "sets a device by id" do
      @nest.set_device(ENV['NEST_DEVICE_SERIAL_NUMBER'])
      expect(@nest.device()['serial_number']).to match ENV['NEST_DEVICE_SERIAL_NUMBER']
    end

    it "gets the device" do
      d = @nest.device
      expect(d['serial_number']).to match ENV['NEST_DEVICE_SERIAL_NUMBER']
    end

    it "gets the status" do
      expect(@nest.device['mac_address']).to match(/(\d|[a-f]|[A-F])+/)
    end

    it "gets the pubic ip address" do
      expect(@nest.public_ip).to match(/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})?$/)
    end

    it "gets the leaf status" do
      expect(@nest.leaf?).to_not be_nil
    end

    it "gets away status" do
      expect(@nest.away?).to_not be_nil
    end

    it "sets away status" do
      @nest.away = true
      expect(@nest.away?).to be(true)
      @nest.away = false
      expect(@nest.away?).to be(false)
    end

    it "gets the current temperature" do
      expect(@nest.current_temperature).to be_a_kind_of(Numeric)
      expect(@nest.current_temp).to be_a_kind_of(Numeric)
    end

    it "gets the relative humidity" do
      expect(@nest.humidity).to be_a_kind_of(Numeric)
    end

    it "gets the temperature" do
      expect(@nest.temperature).to be_a_kind_of(Numeric)
      expect(@nest.temp).to be_a_kind_of(Numeric)
    end

    it "gets the low temperature" do
      expect(@nest.temperature_low).to be_a_kind_of(Numeric)
      expect(@nest.temp_low).to be_a_kind_of(Numeric)
    end

    it "gets the high temperature" do
      expect(@nest.temperature_high).to be_a_kind_of(Numeric)
      expect(@nest.temp_high).to be_a_kind_of(Numeric)
    end

    it "sets the temperature" do
      @nest.temp = '67'
      expect(@nest.temp.round).to eq(67)

      @nest.temperature = '67'
      expect(@nest.temperature.round).to eq(67)
    end

    it "sets the low temperature" do
      @nest.temp_low = '60'
      expect(@nest.temp_low.round).to eq(60)

      @nest.temperature_low = '60'
      expect(@nest.temperature_low.round).to eq(60)
    end

    it "sets the high temperature" do
      @nest.temp_high = '85'
      expect(@nest.temp_high.round).to eq(85)

      @nest.temperature_high = '85'
      expect(@nest.temperature_high.round).to eq(85)
    end

    it "sets the temperature in celsius" do
      @nest.temperature_scale = :celsius
      @nest.temperature = '19.44'
      expect(@nest.temperature).to eq(19.44)
    end

    it "sets the temperature in kelvin" do
      @nest.temp_scale = :kelvin
      @nest.temperature = '292.6'
      expect(@nest.temperature).to eq(292.6)
    end

    it "gets the target temperature time" do
      expect(@nest.target_temp_at).to_not be_nil # (DateObject or false)
      expect(@nest.target_temperature_at).to_not be_nil # (DateObject or false)
    end

    it "gets the fan status" do
      expect(%w[on auto]).to include(@nest.fan_mode)
    end

    it "sets the fan mode" do
      @nest.fan_mode = "on"
      expect(@nest.fan_mode).to eq("on")
      @nest.fan_mode = "auto"
      expect(@nest.fan_mode).to eq("auto")
    end

  end
end
