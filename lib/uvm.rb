#!/usr/bin/env ruby

require_relative "uvm/version"
require_relative "uvm/uvm"

module Uvm
  @version_manager = Uvm.new

  class CLIDispatch
    def initialize version_manager, options
      @version_manager = version_manager
      @options = options
    end

    def dispatch
      raise "No options provided" if @options.nil? or @options.empty?

      @options.each_key do |key|
        method_name = "dispatch_#{key}"
        if self.respond_to? method_name
          return self.public_send(method_name)
        end
      end

      raise "Unknown command"
    end

    def dispatch_available
      o = {
        beta: @options['--beta'],
        patch: @options['--patch'],
        all: @options['--all']  
      }

      available = @version_manager.available(**o)

      $stderr.puts "Available Unity versions:"
      available.each do |a|
        $stdout.puts "  #{a}"
      end
    end

    def dispatch_installed
      installed = @version_manager.installed
      $stderr.puts "Installed Unity versions:"
      if installed.empty?
        $stderr.puts "None"
      else
        installed.each do |i|
          version = i.delete :version

          annotations = i.select do |_, is_true|
            is_true
          end.map(&:first)

          if annotations.empty?
            puts "  #{version}"
          else
            puts "  #{version} [#{annotations.join ", "}]"
          end
        end
      end
    end

    def dispatch_install           
      @version_manager.install(**create_install_opts)
    end

    def dispatch_uninstall            
      @version_manager.uninstall(**create_install_opts)
    end

    def dispatch_local
      begin
        local = @version_manager.local
        if local.nil?
          abort "Current directory is not a Unity project"
        else
          $stdout.puts local[:version]
        end
      rescue => e
        abort e.message
      end
    end

    def dispatch_global
      begin
        global = @version_manager.global
        $stdout.puts global
      rescue => e
        abort e.message
      end
    end

    def dispatch_link
      v = @options['<version>'] || @version_manager.local_version
      begin
        new_path = @version_manager.link version: v
      rescue ArgumentError => e
        abort e.message
      rescue => e
        $stderr.puts "Version #{v} isn't available"
        $stderr.puts "Available versions are:"
        $stderr.puts @version_manager.available
        abort
      end
      $stdout.puts "Linked #{v} : #{UnityLink} -> #{new_path}"
    end

    def dispatch_clear
      begin
        version = @version_manager.global
        @version_manager.clear
        $stdout.puts "Cleared linked Unity version #{version}"
      rescue => e
        abort e.message
      end
    end

    def dispatch_launch
      o = {}
      o.merge!({:project_path => @options['<project-path>']}) if @options['<project-path>']
      o.merge!({:platform => @options['<platform>']}) if @options['<platform>']
      
      @version_manager.launch(**o)
    end

    private

    def create_install_opts
      {
        version: @options['<version>'],
        ios: (@options['--ios'] || @options['--mobile'] || @options['--all']),
        android: (@options['--android'] || @options['--mobile'] || @options['--all']),
        webgl: (@options['--webgl'] || @options['--mobile'] || @options['--all']),
        linux: (@options['--linux'] || @options['--desktop'] || @options['--all']),
        windows: (@options['--windows'] || @options['--desktop'] || @options['--all'])
      }.delete_if { |_key, value| !value }
    end
  end

  def self.dispatch options
    d = CLIDispatch.new Uvm.new, options
    d.dispatch()
  end
end
