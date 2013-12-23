# fork of https://github.com/hotchpotch/fluent-plugin-graphite
# Apache License, Version 2.0

module Fluent
  class GraphiteOutput < BufferedOutput
    Fluent::Plugin.register_output('graphite2', self)

    config_param :flush_interval, :time, :default => 10
    config_param :host, :string, :default => 'localhost'
    config_param :port, :string, :default => '2003'
    config_param :key_prefix, :string, :default => 'stats'
    config_param :default_type, :string, :default => 'gauge'
    config_param :count_pattern, :string, :default => nil
    config_param :gauge_pattern, :string, :default => nil
    config_param :timer_pattern, :string, :default => nil

    attr_reader :graphite

    def initialize
      super
    end

    def configure(conf)
      super
      @graphite = Graphite.new(host, port)
    end

    def start
      super
    end

    def shutdown
      super
    end

    def format(tag, time, record)
      record.to_msgpack
    end

    def write(chunk)
      timestamp = Time.now.to_i

      counts = Hash.new {|h,k| h[k] = 0 }
      timers = Hash.new {|h,k| h[k] = [] }
      gauges = {}

      chunk.msgpack_each {|record|
        record.each do |k, v|
          if count_pattern and k =~ /#{count_pattern}/
            counts[k] += v
          elsif gauge_pattern and k =~ /#{gauge_pattern}/
            gauges[k] = v
          elsif timer_pattern and k =~ /#{timer_pattern}/
            timers[key] << v
          else
            if default_type == 'count'
                counts[k] += v
            elsif default_type == 'gauge'
                gauges[k] = v
            elsif default_type == 'timer'
                timers[key] << v
            end
          end
        end
      }

      post_data(counts, timers, gauges, timestamp)
    end

    def post_data(counts, timers, gauges, timestamp)
      message = []

      counts.each {|key, value|
        message << "#{key_prefix}.counts.#{key} #{value} #{timestamp}"
      }

      gauges.each {|key, value|
        message << "#{key_prefix}.gauges.#{key} #{value} #{timestamp}"
      }

      # TODO: implements
      timers

      @graphite.post(message.join("\n") + "\n")
    end

    class Graphite
      attr_reader :host, :port
      def initialize(host, port)
        @host = host
        @port = port
      end

      def post(message)
        puts "post: " + message
        TCPSocket.open(host, port) {|socket|
          socket.write(message)
        }
      end
    end
  end
end
