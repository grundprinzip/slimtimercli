require 'fileutils'
require 'net/http'
require 'rubygems'
require 'active_record'
require 'active_support'
require 'yaml'
require 'optparse'
require 'ostruct'

require "slimtimercli/entities"
require "slimtimercli/slim_timer"
require "slimtimercli/version"
require "slimtimercli/helper"

module Slimtimercli

  class CommandLine

    # Include Helper module
    include Helper

    def initialize(args, output = $stdout)
      @args = args
      @out = output

      deprecated_calls

      @options = parse(args)
    end

    def create
      st = login
      if st.create_task(@options.task_name)
        dump_to_file(st.tasks, tasks_file)
        @out.puts "Task #{name} successfully created."
      end
    end

    def tasks(show = true)
      tasks = load_tasks
      return tasks unless show

      tasks.each do |t|
        @out.puts t.name
      end
    end

    def setup
      config = load_config

      @out.puts "Slimtimer Login Credentials\n"
      @out.print "E-Mail: "
      config["email"] = $stdin.gets.strip

      begin
        @out.print "Password: "
        system("stty -echo")
        config["password"] = $stdin.gets.strip
      ensure
        system("stty echo")
      end

      # Include the newline here so that both prompts are on the same line
      @out.print "\nAPI Key: "
      config["api_key"] = $stdin.gets.strip

      save_config(config)
    end

    def start
      if File.exists?(current_file)
        @out.puts "Need to stop the other task first"
        return false
      end

      info = {"task" =>  @options.task_name,
        "start_time" => Time.now}

      #Find task in tasks yml
      t = load_tasks.find {|t| t.name == info["task"]}
      unless t
        @out.puts "Task not found in list. Reload List?"
        return false
      end

      dump_to_file(info, current_file)
      return true
    end

    def stop

      if @options.force
        rm_current
        @out.puts "Forced ending of task, no entry to slimtimer.com written"
        return true
      end


      begin
        info = load_file(current_file)
      rescue
        puts "You must start a task before you finish it"
        return false
      end

      #Find task in tasks yml
      t = load_tasks.find {|t| t.name == info["task"]}
      unless t
        @out.puts "Task not found in list. Reload List?"
        return false
      end
      raise  unless t

      st = login
      result = st.create_time_entry(t, info["start_time"],
        (Time.now - info["start_time"]).to_i)

      # Delete yml file
      if result
        rm_current

        # Output
        @out.puts "Wrote new Entry for #{t.name}, duration #{result["duration_in_seconds"] / 60}m"
        return true
      else
        @out.puts "Coult not write new entry, please try again"
        return false
      end
    end

    def run
      send(@options.run.to_sym)
    end

    alias_method :end, :stop

    private

    # This method checks if the first parameter in args needs to
    # be transformed to the new one
    def deprecated_calls
      case @args[0]
      when "start" then @args[0] = "-s"
      when "end" then @args[0] = "-e"
      when "create_task" then @args[0] = "-c"
      when "tasks" then @args[0] = "-t"
      when "setup" then @args[0] = "--setup"
      else
        puts "Unknown command, listing tasks..."
        @args[0] = "-t"
      end
    end

    def load_tasks(force = false)
      config = load_config
      st = SlimTimer.new(config["email"], config["password"],
        config["api_key"])

      tasks = []
      if !File.exists?(tasks_file) ||
         File.mtime(tasks_file) < (Time.now - 60 * 60 *24) || force
        st.login
        tasks = st.tasks
        dump_to_file(tasks, tasks_file)
      else
        tasks = load_file(tasks_file)
      end
      tasks
    end
  end
end
