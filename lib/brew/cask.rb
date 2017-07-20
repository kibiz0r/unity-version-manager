require "open3"

module Brew
  class Cask

    def search pattern
      results = []

      Open3.popen3("brew cask search #{pattern}") {|_stdin,stdout,_stderr,_thread|
        results = stdout.read.chomp.lines.map { |i| i.chomp }
      }

      results.select {|item| !item.start_with? "==>" }
    end

    def list
      results = []

      Open3.popen3("brew cask list") { |_stdin,stdout,_stderr,_thread|
        results = stdout.read.chomp.lines.map { |i| i.chomp }
      }

      results
    end

    def install *names
      exec("brew cask install #{names * ' '}")
    end

    def uninstall *names
      exec("brew cask uninstall #{names * ' '}")
    end
  end
end
