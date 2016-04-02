require 'rubygems'
require 'httparty'
require 'json'
require 'uri'

module NestThermostat
  class Nest
    attr_accessor :login_url, :user_agent, :auth, :login, :token, :user_id,
      :transport_url, :transport_host, :headers, :current_structure, :current_device

    attr_reader :temperature_scale

    def initialize(config = {})
      raise 'Please specify your nest email' unless config[:email]
      raise 'Please specify your nest password' unless config[:password]

      # User specified information
      self.temperature_scale = config[:temperature_scale] || config[:temp_scale] || :fahrenheit
      @login_url = config[:login_url] || 'https://home.nest.com/user/login'
      @user_agent = config[:user_agent] ||'Nest/1.1.0.10 CFNetwork/548.0.4'

      # Login and get token, user_id and URLs
      perform_login(config[:email], config[:password])

      @token = @auth["access_token"]
      @user_id = @auth["userid"]
      @transport_url = @auth["urls"]["transport_url"]
      @transport_host = URI.parse(@transport_url).host
      @headers = {
        'Host' => self.transport_host,
        'User-Agent' => self.user_agent,
        'Authorization' => 'Basic ' + self.token,
        'X-nl-user-id' => self.user_id,
        'X-nl-protocol-version' => '1',
        'Accept-Language' => 'en-us',
        'Connection' => 'keep-alive',
        'Accept' => '*/*'
      }
      self.set_default_structure unless not config[:use_default_structure]
      self.set_default_device unless not config[:use_default_device]
    end

    def structures
      status = self.status
      structures = []
      structure_ids = status['user'][self.user_id]['structures']
      structure_ids.each do |structure_id|
        structure_id = structure_id.gsub /structure./i, ''
        structure_data = status['structure'][structure_id]
        structure_name = structure_data['name']
        devices = []
        structure_data['devices'].each do |device_id|
          device_id = device_id.gsub /device./i, ''
          device_data = status['device'][device_id]
          device_where_id = device_data['where_id']
          wheres = status['where'][structure_id]['wheres']
          device_name = (wheres.select { |where|  where['where_id'] ==  device_where_id })[0]['name']
          device_data['id'] = device_id
          device_data['name'] = device_name
          devices.push(device_data)
        end
        structure_data['id'] = structure_id
        structure_data['name'] = structure_name
        structure_data['devices'] = devices
        structures.push(structure_data)
      end
      structures
    end

    def set_structure(id_or_name)
      structures = self.structures.select { |structure| structure['id'] == id_or_name || structure['name'] == id_or_name }
      @current_structure = structures[0]
    end

    def set_default_structure
      @current_structure = self.structures()[0]
    end

    def structure
      raise 'Please select a structure' unless @current_structure
      @current_structure
    end

    def structure_id
      self.structure()['id']
    end

    def devices
      self.structure()['devices']
    end

    def set_device(id_or_name)
      devices = self.devices().select { |device| device['id'] == id_or_name || device['name'] == id_or_name  }
      raise 'No devices found' unless devices.length > 0
      @current_device = devices[0]
    end

    def set_default_device
      @current_device = self.devices()[0]
    end

    def device
      raise 'Please select a structure' unless @current_structure
      raise 'Please select a device' unless @current_device
      @current_device
    end

    def device_id
      self.device()['id']
    end

    def status
      request = HTTParty.get("#{self.transport_url}/v2/mobile/user.#{self.user_id}", headers: self.headers) rescue nil
      result = JSON.parse(request.body) rescue nil
    end

    def mac_address
      status["track"][self.device_id]["mac_address"].strip
    end

    def public_ip
      status["track"][self.device_id]["last_ip"].strip
    end

    def leaf?
      status["device"][self.device_id]["leaf"]
    end

    def humidity
      status["device"][self.device_id]["current_humidity"]
    end

    def current_temperature
      convert_temp_for_get(status["shared"][self.device_id]["current_temperature"])
    end
    alias_method :current_temp, :current_temperature

    def temperature
      convert_temp_for_get(status["shared"][self.device_id]["target_temperature"])
    end
    alias_method :temp, :temperature

    def temperature_low
      convert_temp_for_get(status["shared"][self.device_id]["target_temperature_low"])
    end
    alias_method :temp_low, :temperature_low

    def temperature_high
      convert_temp_for_get(status["shared"][self.device_id]["target_temperature_high"])
    end
    alias_method :temp_high, :temperature_high

    def temperature=(degrees)
      degrees = convert_temp_for_set(degrees)
      raise 'You must select a device before continuing' unless @current_device
      request = HTTParty.post(
        "#{self.transport_url}/v2/put/shared.#{self.device_id}",
        body: %Q({"target_change_pending":true,"target_temperature":#{degrees}}),
        headers: self.headers
      ) rescue nil
    end
    alias_method :temp=, :temperature=

    def temperature_low=(degrees)
      degrees = convert_temp_for_set(degrees)
      raise 'You must select a device before continuing' unless @current_device
      request = HTTParty.post(
          "#{self.transport_url}/v2/put/shared.#{self.device_id}",
          body: %Q({"target_change_pending":true,"target_temperature_low":#{degrees}}),
          headers: self.headers
      ) rescue nil
    end
    alias_method :temp_low=, :temperature_low=

    def temperature_high=(degrees)
      degrees = convert_temp_for_set(degrees)
      raise 'You must select a device before continuing' unless @current_device
      request = HTTParty.post(
          "#{self.transport_url}/v2/put/shared.#{self.device_id}",
          body: %Q({"target_change_pending":true,"target_temperature_high":#{degrees}}),
          headers: self.headers
      ) rescue nil
    end
    alias_method :temp_high=, :temperature_high=

    def target_temperature_at
      epoch = status["device"][self.device_id]["time_to_target"]
      epoch != 0 ? Time.at(epoch) : false
    end
    alias_method :target_temp_at, :target_temperature_at

    def away?
      status["structure"][self.structure_id]["away"]
    end

    def away=(state)
      request = HTTParty.post(
        "#{self.transport_url}/v2/put/structure.#{self.structure_id}",
        body: %Q({"away_timestamp":#{Time.now.to_i},"away":#{!!state},"away_setter":0}),
        headers: self.headers
      ) rescue nil
    end

    def temperature_scale=(scale)
      if %i[kelvin celsius fahrenheit].include?(scale)
        @temperature_scale = scale
      else
        raise ArgumentError, "#{scale} is not a valid temperature scale"
      end
    end
    alias_method :temp_scale=, :temperature_scale=

    def fan_mode
      status["device"][self.device_id]["fan_mode"]
    end

    def fan_mode=(state)
      raise 'You must select a device before continuing' unless @current_device
      HTTParty.post(
        "#{self.transport_url}/v2/put/device.#{self.device_id}",
        body: %Q({"fan_mode":"#{state}"}),
        headers: self.headers
      ) rescue nil
    end

    def method_missing(name, *args, &block)
      if %i[away leaf].include?(name)
        warn "`#{name}' has been replaced with `#{name}?'. Support for " +
             "`#{name}' without the '?' will be dropped in future versions."
        return self.send("#{name}?", *args)
      end

      super
    end

    private

    def perform_login(email, password)
      login_request = HTTParty.post(
                        self.login_url,
                        body: { username: email, password: password },
                        headers: { 'User-Agent' => self.user_agent }
                      )

      @auth ||= JSON.parse(login_request.body) rescue nil
      raise 'Invalid login credentials' if auth.has_key?('error') && @auth['error'] == "access_denied"
    end

    def convert_temp_for_get(degrees)
      case @temperature_scale
      when :fahrenheit then c2f(degrees).round(5)
      when :kelvin     then c2k(degrees).round(5)
      when :celsius    then degrees
      end
    end

    def convert_temp_for_set(degrees)
      case @temperature_scale
      when :fahrenheit then f2c(degrees).round(5)
      when :kelvin     then k2c(degrees).round(5)
      when :celsius    then degrees
      end
    end

    def k2c(degrees)
      degrees.to_f - 273.15
    end

    def c2k(degrees)
      degrees.to_f + 273.15
    end

    def c2f(degrees)
      degrees.to_f * 9.0 / 5 + 32
    end

    def f2c(degrees)
      (degrees.to_f - 32) * 5 / 9
    end
  end
end
