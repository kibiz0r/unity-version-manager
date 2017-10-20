require 'plist'
require 'fileutils'
require 'brew/cask'
require 'brew/tap'

module Uvm

  Applications = "/Applications"
  UnityLink = "#{Applications}/Unity"
  UnityContents="#{UnityLink}/Unity.app/Contents"

  class Uvm

    attr_reader :tap, :cask

    def initialize tap: nil, cask: nil
      ensure_link
      @tap = tap.nil? ? Brew::Tap.new : tap
      @cask = cask.nil? ? Brew::Cask.new : cask
    end

    # list available versions to download
    def available beta: false, patch: false, all: false, **options

      version_types = []
      if(beta || all)
        tap.ensure "wooga/unityversions-beta"
        version_types << 'b'
      end

      if patch || all
        tap.ensure "wooga/unityversions-patch"
        version_types << 'p'
      end

      if version_types.empty? || all
        tap.ensure "wooga/unityversions"
        version_types << 'f'
      end

      cask.search("unity").select do |cask|
        cask.match "unity@.*?(#{version_types.join('|')}).*"
      end.map do |cask|
        cask.split("@")[1]
      end
    end

    def installed_versions
      pattern = File.join Applications, "Unity-*"

      Dir.glob(pattern).reject do |u|
        u.match(version_regex).nil?
      end.map do |u|
        u.match(version_regex) { |m| m[1] }
      end
    end

    # returns a list of installed unity version in the form of
    # major.minor.path(p|f)level
    # if no unity versions are installed returns an empty list
    def installed mark_active: true, **options
      versions = installed_versions

      global = mark_active ? global(**options) : ""
      local = mark_active ? local_version : ""

      versions.map do |u|
        {
          global: u == global,
          local: u == local,
          version: u
        }
      end
    end

    # install unity via brew cask
    def install version: :latest, **support_package_options
      ensure_tap_for_version version

      installed = cask.list.select {|cask| cask.include? "@#{version}"}

      to_install = []
      to_install << cask_name_for_type_version(:unity, version)
      to_install += check_support_packages version, **support_package_options
      to_install = to_install - installed

      cask.install(*to_install) unless to_install.empty?
    end

    # uninstall unity via brew cask
    def uninstall version: :latest, **support_package_options
      ensure_tap_for_version version

      installed = cask.list.select {|cask| cask.include? "@#{version}"}
      to_uninstall = check_support_packages version, **support_package_options

      to_uninstall = installed if to_uninstall.empty?
      cask.uninstall(*to_uninstall) unless to_uninstall.empty?
    end

    # launch active unity with project path and platform
    def launch project_path: File.expand_path(Dir.pwd), platform: "android", **_options
      project_str = ""
      project_str = "-projectPath '#{project_path}'" if is_a_unity_project_dir? project_path

      version = local_version
      unity_path =
        if local_version.nil?
          File.join Applications, "Unity"
        else
          File.join Applications, "Unity-" + version
        end

      exec "open -n #{unity_path}/Unity.app --args -buildTarget #{platform} #{project_str}"
    end

    def local_version
      versions_file = File.absolute_path File.join("ProjectSettings", "ProjectVersion.txt")

      if File.exist? versions_file
        content = ""

        File.open(versions_file) { |f| content = f.read }

        match_data = content.match(/m_EditorVersion: (.*)/)

        if match_data and match_data.length > 1
          return match_data[1]
        end
      end

      nil
    end

    # Detects Unity version in current project
    def local **_options
      if version = local_version
        {
          installed: installed_versions.include?(version),
          version: version
        }
      else
        nil
      end
    end

    # returns globally-linked unity version
    # returns empty string when no version is linked
    def global **_options
      plist_path = File.join UnityContents, "Info.plist"

      if File.exist? plist_path
        plist = Plist::parse_xml plist_path
        return plist['CFBundleVersion']
      end
      ""
    end

    # Sets link to specified unity version.
    # Raise error when version parameter is not in form of major.minor.path(p|f)level
    # or specified version is not installed.
    def link version: :latest, **_options
      unless version =~ version_regex
        raise ArgumentError, "Invalid format '#{version}' - please try a version in format `x.x.x(f|p)x`"
      end

      unless installed_versions.include? version
        raise "Invalid version '#{version}' - version is not available"
      end

      desired_version = File.join Applications, "Unity-" + version

      FileUtils.rm_f UnityLink if File.exist? UnityLink
      FileUtils.ln_s desired_version, UnityLink, force: true

      desired_version
    end

    # Clears current link to active unity
    # Raise error when no unity version is activated
    def clear **_options
      unless File.exist? UnityLink
        raise "Invalid operation - no version active"
      end

      FileUtils.rm_f UnityLink
    end

    def cask_name_for_type type
      type = "unity-#{type}-support-for-editor" unless type.to_s.eql? 'unity'
      type.to_s
    end

    def cask_name_for_type_version type, version
      cask_name_for_type(type) + "@" + version.to_s
    end

    protected

    def ensure_tap_for_version(version)
      tap.ensure "wooga/unityversions" if version.include? 'f'
      tap.ensure "wooga/unityversions-patch" if version.include? 'p'
      tap.ensure "wooga/unityversions-beta" if version.include? 'b'
    end

    def check_support_packages version, **options
      options.reduce([]) { |packages, (k,v)|
        packages << cask_name_for_type_version(k, version) if v
      }
    end

    def is_a_unity_project_dir? path
      contents = Dir[File.join(path, "*")].map { |c| File.basename(c) }
      contents.include?("Assets") and contents.include?("ProjectSettings")
    end

    def version_regex
      /(\d+\.\d+\.\d+((f|p|b)\d+)?)$/
    end

    def ensure_link
      if !File.symlink? UnityLink and File.directory? UnityLink
        new_dir_name = File.join Applications, "Unity-" + current
        FileUtils.mv UnityLink, new_dir_name
        FileUtils.ln_s new_dir_name, UnityLink, force: true
      end
    end
  end
end
