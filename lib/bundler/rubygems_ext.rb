require 'pathname'

if defined?(Gem::QuickLoader)
  # Gem Prelude makes me a sad panda :'(
  Gem::QuickLoader.load_full_rubygems_library
end

require 'rubygems'
require 'rubygems/specification'

module Bundler
  class DepProxy

    attr_reader :required_by, :__platform, :dep

    def initialize(dep, platform)
      @dep, @__platform, @required_by = dep, platform, []
    end

    def hash
      @hash ||= dep.hash
    end

    def ==(o)
      dep == o.dep && __platform == o.__platform
    end

    alias eql? ==

    def type
      @dep.type
    end

    def to_s
      @dep.to_s
    end

  private

    def method_missing(*args)
      @dep.send(*args)
    end

  end
end

module Gem
  @loaded_stacks = Hash.new { |h,k| h[k] = [] }

  module MatchPlatform
    def match_platform(p)
      Gem::Platform::RUBY == platform or
      platform.nil? or p == platform or
      Gem::Platform.new(platform).to_generic == p
    end
  end

  class Specification
    attr_accessor :source, :location, :relative_loaded_from

    alias_method :rg_full_gem_path, :full_gem_path
    alias_method :rg_loaded_from,   :loaded_from

    include MatchPlatform

    def full_gem_path
      source.respond_to?(:path) ?
        Pathname.new(loaded_from).dirname.expand_path.to_s :
        rg_full_gem_path
    end

    def loaded_from
      relative_loaded_from ?
        source.path.join(relative_loaded_from).to_s :
        rg_loaded_from
    end

    def load_paths
      require_paths.map do |require_path|
        if require_path.include?(full_gem_path)
          require_path
        else
          File.join(full_gem_path, require_path)
        end
      end
    end

    def groups
      @groups ||= []
    end

    def git_version
      if @loaded_from && File.exist?(File.join(full_gem_path, ".git"))
        sha = Dir.chdir(full_gem_path){ `git rev-parse HEAD`.strip }
        " #{sha[0..6]}"
      end
    end

    def to_gemfile(path = nil)
      gemfile = "source :gemcutter\n"
      gemfile << dependencies_to_gemfile(nondevelopment_dependencies)
      unless development_dependencies.empty?
        gemfile << "\n"
        gemfile << dependencies_to_gemfile(development_dependencies, :development)
      end
      gemfile
    end

    def nondevelopment_dependencies
      dependencies - development_dependencies
    end

    def add_bundler_dependencies(*groups)
      groups = [:default] if groups.empty?
      Bundler.definition.dependencies.each do |dep|
        if dep.groups.include?(:development)
          self.add_development_dependency(dep.name, dep.requirement.to_s)
        elsif (dep.groups & groups).any?
          self.add_dependency(dep.name, dep.requirement.to_s)
        end
      end
    end

  private

    def dependencies_to_gemfile(dependencies, group = nil)
      gemfile = ''
      if dependencies.any?
        gemfile << "group :#{group} do\n" if group
        dependencies.each do |dependency|
          gemfile << '  ' if group
          gemfile << %|gem "#{dependency.name}"|
          req = dependency.requirements_list.first
          gemfile << %|, "#{req}"| if req
          gemfile << "\n"
        end
        gemfile << "end\n" if group
      end
      gemfile
    end

  end

  class Dependency
    attr_accessor :source, :groups

    alias eql? ==

    def to_yaml_properties
      instance_variables.reject { |p| ["@source", "@groups"].include?(p.to_s) }
    end

    def to_lock
      out = "  #{name}"
      unless requirement == Gem::Requirement.default
        out << " (#{requirement.to_s})"
      end
      out
    end
  end

  class Platform
    JAVA  = Gem::Platform.new('java')
    MSWIN = Gem::Platform.new('mswin32')
    MING  = Gem::Platform.new('x86-mingw32')

    GENERIC_CACHE = {}

    class << RUBY
      def to_generic ; self ; end
    end

    GENERICS = [JAVA, MSWIN, MING, RUBY]

    def hash
      @cpu.hash + @os.hash + @version.hash
    end

    alias eql? ==

    def to_generic
      GENERIC_CACHE[self] ||= GENERICS.find { |p| self =~ p } || RUBY
    end
  end
end
