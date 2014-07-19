gem 'bundler'
require 'bundler'
Bundler.require

require 'pry'
require 'yaml'

Docker.url = 'unix:///tmp/docker.sock'

class Manifest
  def initialize

  end

  # formatters
  def manifest
    return @manifest if defined?(@manifest)

    data = if ENV['MANIFEST_URL']
      open(ENV['MANIFEST_URL'])
    else
      File.read('manifest.yml')
    end

    @manifest = YAML.load(data)[ENV['NODE_NAME']]
    @manifest.deep_symbolize_keys!
  end

  def repositories
    manifest[:repositories]
  end

  def format_links links
    links ||= []
    links.map do |name, val|
      "#{name}:#{val}"
    end
  end

  def format_env spec
    envs = spec[:env] || {}

    envs[:VIRTUAL_HOST] = spec[:host] if spec[:host]

    envs.map do |name, val|
      "#{name}=#{val}"
    end
  end

  # mappings
  def remove_old name, spec
    begin 
      old_container = Docker::Container.get(name)
      return :exists if spec[:keep]
      old_container.kill
      old_container.delete
    rescue Docker::Error::NotFoundError
    end
  end

  def create name, spec, addl = {}
    opts = {
      'name'  => name,
      'Image' => spec.delete(:image),
      'Env'   => format_env(spec) }

    Docker::Container.create opts.merge(addl)
  end

  def start container, spec
    container.start \
      'Links' => format_links(spec.delete(:links)),
      'Binds' => format_links(spec.delete(:volumes))
  end
end
