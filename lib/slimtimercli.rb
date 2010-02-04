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

module Slimtimercli
  module Helper
    def login
      config = Helper::load_config
      st = SlimTimer.new(config["email"], config["password"],
        config["api_key"])
      st.login

      st
    end

    def root
      @root ||= if File.exists? ENV['XDG_CONFIG_HOME']
                  File.join(ENV['XDG_CONFIG_HOME'], "slimtimer")
                else
                  File.join(ENV["HOME"], ".slimtimer")
                end
    end

    def config_file
      File.join(root, "config.yml")
    end

    def tasks_file
      File.join(root, "tasks.yml")
    end

    def current_file
      File.join(root, "current.yml")
    end

    def check_and_create_dir
      raise "Home DIR not set!" unless ENV["HOME"]

      unless File.directory?(root)
        FileUtils.mkdir(root)
      end
    end

    def load_config
      check_and_create_dir

      unless File.exists?(config_file)
        File.open( config_file, 'w' ) do |out|
          YAML.dump({}, out )
        end
      end
      load_file(config_file)
    end

    def save_config(config)
      dump_to_file(config, config_file)
    end

    def load_file(file)
      File.open( file ) { |yf| YAML::load( yf ) }
    end

    def dump_to_file(object, file)
      check_and_create_dir
      File.open( file, 'w' ) do |out|
        YAML.dump(object, out )
      end
    end

    def rm_current
      FileUtils.rm(current_file) if
        File.exists?(current_file)
    end

    def parse(args)

      if !args || args.empty?
        warn "Need to specify arguments, run slimtimer -h for help"
        exit 2

      end

      options = OpenStruct.new
      options.force = false

      opts = OptionParser.new do |opts|

        opts.banner = "Usage: slimtimer [options]"

        opts.on("-s TASK", "--start TASK",
          "Start a TASK given by the task name") do |t|

          options.run = "start"
          options.task_name = t
        end

        opts.on("-c TASK", "--create TASK",
          "Create a ne task by the given name") do |t|
          options.run = "create"
          options.task_name = t
        end

        opts.on("-e", "--end" ,"Stops time recording for the given task") do
          options.run = "stop"
        end

        opts.on("-t", "--tasks", "Prints all available tasks") do
          options.run = "tasks"
        end

        opts.on("-f", "--force", "Force deletion of tasks") do
          options.force = true
        end

        opts.on("--setup", "Setup your account") do
          options.run = "setup"
        end

        opts.on_tail("-h", "Shows this note") do
          puts opts
          exit
        end

        opts.on("--help", "Show verbose help") do
          @out.puts <<-HELP
SlimTimer is a tool to record your time spend on a
task. SlimTimer CLI allows you to controll your
SlimTimer directly from where you spend most of your
time - on the command line. To use SlimTimer proceed
with the following steps:

The first time you need to setup SlimTimer CLI with

  slimtimer setup

Now it will ask for your email and password and API key
to use with your account. These information will be stored
in #{config_file}

To create a task run

  slimtimer create_task my_shiny_task

To spend some time on the task you have to make the timer run

  slimtimer start my_shiny_task

When you finished working on a task, you can call

  slimtimer end

This will write the time spend back to SlimTimer.com.
Finally you can run

  slimtimer tasks

To show all your tasks available.
HELP
          exit
        end
      end

      begin
        opts.parse!(args)
      rescue
        puts $!.message
        exit
      end
      options
    end
  end

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
