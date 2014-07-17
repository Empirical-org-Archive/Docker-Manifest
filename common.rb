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
    @manifest = YAML.load(File.read('manifest.yml'))
    @manifest.deep_symbolize_keys!
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

  # endpoints
  def run
    args = ARGV.dup
    name = args.shift
    run_name = "#{name}_run_001"
    spec = manifest[:containers][name.to_sym]

    container = create run_name, spec, \
      'Cmd' => args

    start container

    container.attach { |stream, chunk| puts chunk }
    container.delete
  end

  def gen
    manifest[:containers].each do |name, spec|
      name = name.to_s
      next if remove_old(name, spec) == :exists
      container = create name, spec
      start container, spec
    end
  end
end
