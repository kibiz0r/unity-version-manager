require 'thor'
require 'fileutils'

module UVM
  UNITY_LINK='/Applications/Unity'
  UNITY_CONTENTS="#{UNITY_LINK}/Unity.app/Contents"
  UNITY_INSTALL_LOCATION='/Applications'

  class CLI < Thor

    desc "list", "list unity versions available"
    def list
      installed = Lib.list
      current = Lib.current
      puts installed.map {|i| current.include?(i) ? i + " [active]" : i }
    end

    desc "use VERSION", "Use specific version of unity"
    def use version
      unless version =~ Lib.version_regex
        puts "Invalid format '#{version}' - please try a version in format `X.X.X`"
        exit
      end

      desired_version = File.join(UNITY_INSTALL_LOCATION,"Unity"+version)

      unless Dir.exists? desired_version
        puts "Version #{version} isn't available "
        puts "Available versions are -"
        list
        exit
      end

      #Current unity dir isn't a symlink and needs to be renamed
      if !File.symlink?(UNITY_LINK) and File.directory?(UNITY_LINK)
        new_dir_name = File.join(UNITY_INSTALL_LOCATION,"Unity"+Lib.current)
        FileUtils.mv(UNITY_LINK, new_dir_name)
      end

      FileUtils.rm(UNITY_LINK) if File.exists? UNITY_LINK
      FileUtils.ln_s(desired_version, UNITY_LINK, :force => true)

      puts "Using #{version} : #{UNITY_LINK} -> #{desired_version}"
    end

    desc "detect", "Find which version of unity was used to generate the project in current dir"
    def detect
      version = `find . -name ProjectVersion.txt | xargs cat | grep EditorVersion`
      match_data = version.match /m_EditorVersion: (.*)/

      if match_data and match_data.length > 1
        puts match_data[1]
      else
        puts "Couldn't detect project version"
      end
    end

    desc "current", "Print the current version in use"
    def current
      if Lib.current
        puts Lib.current
      else
        puts "No unity version detected"
      end
    end
  end

  class Lib
    def self.current
      plist_path = File.join(UNITY_CONTENTS,"Info.plist")
      if File.exists? plist_path
        `/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' #{plist_path}`.split("f").first
      end
    end

    def self.list
      installed = `find #{UNITY_INSTALL_LOCATION} -name "Unity*" -type d -maxdepth 1`.lines
      installed.map{|u| u.match(version_regex){|m| m[1]} }
    end

    def self.version_regex
      /(\d+\.\d+\.\d+$)/
    end
  end
end
