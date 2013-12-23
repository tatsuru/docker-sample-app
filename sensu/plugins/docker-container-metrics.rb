#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class DockerContainerMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.docker"

  option :cgroup_path,
    :description => "path to cgroup mountpoint",
    :short => "-c PATH",
    :long => "--cgroup PATH",
    :default => "/sys/fs/cgroup"

  def run
    `docker ps -notrunc`.each_line do |ps|
      next if ps =~ /^CONTAINER/
      container, image = ps.split /\s+/
      app, sha1 = image.split('/').last.split(':')

      prefix = "#{config[:scheme]}.#{app}.#{sha1}"
      inspect = `docker inspect -format "{{.Config.Env}}"  #{container}`
      task_id = sha1
      if inspect =~ /MESOS_TASK_ID=([^ ]*)/
        task_id = $1
        revision, my_id = task_id.split(/_/)
        prefix = "#{config[:scheme]}.#{revision}.#{my_id}"
      end
      
      timestamp = Time.now.to_i
      ['cpuacct.stat', 'memory.stat'].each do |stat|
        f = [config[:cgroup_path], 'lxc', container, stat].join('/')
        File.open(f, "r").each_line do |l|
          k, v = l.chomp.split /\s+/
          key = [prefix, stat,  k].join('.')
          output key, v, timestamp
        end
      end
    end
    ok
  end

end
