$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'fileutils'
require 'net/http'
require 'rubygems'
require 'active_record'
require 'active_support'
require 'yaml'    

require "slimtimercli/entities"
require "slimtimercli/slim_timer"
require "slimtimercli/version"

module Slimtimercli
  module Helper
    def self.login
      config = Helper::load_config
      st = SlimTimer.new(config["email"], config["password"],
        config["api_key"])
      st.login

      st  
    end

    def self.root
      File.join(ENV["HOME"], ".slimtimer")
    end

    def self.config_file
      File.join(root, "config.yml")
    end

    def self.tasks_file
      File.join(root, "tasks.yml")
    end

    def self.current_file
      File.join(root, "current.yml")
    end

    def self.check_and_create_dir
      raise "Home DIR not set!" unless ENV["HOME"]

      unless File.directory?(root)
        FileUtils.mkdir(root)
      end
    end

    def self.load_config
      check_and_create_dir

      unless File.exists?(File.join(root, "config.yml"))
        File.open( File.join(root, "config.yml"), 'w' ) do |out|
          YAML.dump({}, out )
        end
      end
      load_file("config.yml")
    end

    def self.save_config(config)
      dump_to_file(config, "config.yml")
    end

    def self.load_file(file)
      File.open( File.join(root, file) ) { |yf| YAML::load( yf ) }
    end

    def self.dump_to_file(object, file)
      check_and_create_dir
      File.open( File.join(root, file), 'w' ) do |out|
        YAML.dump(object, out )
      end
    end
  end
    
  def self.create_task
    name = ARGV[1]

    st = Helper::login
    if st.create_task(name)                    
      Helper::dump_to_file(st.tasks, "tasks.yml")
      puts "Task #{name} successfully created."
    end            
  end

  def self.tasks(show= true)
    config = Helper::load_config
    st = SlimTimer.new(config["email"], config["password"],
      config["api_key"])

    if !File.exists?(Helper::tasks_file) ||
       File.mtime(Helper::tasks_file) < (Time.now - 60 * 60 *24)

      st.login
      Helper::dump_to_file(st.tasks, "tasks.yml")
    end

    tasks = Helper::load_file("tasks.yml")

    return tasks unless show

    tasks.each do |t|
      puts t.name
    end
  end

  def self.force_reload
    config = Helper::load_config
    st = SlimTimer.new(config["email"], config["password"],
      config["api_key"])

    st.login
    Helper::dump_to_file(st.tasks, "tasks.yml")
    tasks = Helper::load_file("tasks.yml")

    tasks.each do |t|
      puts t.name
    end
  end

  # This method stores the credentials in the necessary directoyr
  def self.setup
    config = Helper::load_config

    puts "Slimtimer Login Credentials\n"
    print "E-Mail: "
    config["email"] = STDIN.gets.gsub("\n", "")

    print "Password: "
    config["password"] = STDIN.gets.gsub("\n", "")

    print "API Key: "
    config["api_key"] = STDIN.gets.gsub("\n", "")

    Helper::save_config(config)

    # clear the screen
    system("clear")
  end

  def self.help
    puts <<-HELP
SlimTimer is a tool to record your time spend on a
task. SlimTimer CLI allows you to controll your 
SlimTimer directly from where you spend most of your
time - on the command line. To use SlimTimer proceed
with the following steps:

The first time you need to setup SlimTimer CLI with

  slimtimer setup

Now it will ask for your email and password and API key
to use with your account. These information will be stored
in ~/.slimtimer/config.yml

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
  end

  def self.start    
    if ARGV.empty?
      puts "Need to specify a task as argument"
      return false
    end
                    
    if File.exists?(Helper::current_file)
      puts "Need to stop the other task first"
      return false                     
    end
    
    info = {"task" =>  ARGV[1],
      "start_time" => Time.now}

    # dum curent task to file
    Helper::dump_to_file(info, "current.yml")
    return true
  end

  def self.end 
    begin
    info = Helper::load_file("current.yml")
    rescue                                 
      puts "You must start a task before you finish it"
      return false
    end


    #Find task in tasks yml
    t = tasks(false).find {|t| t.name == info["task"]}

    raise "Task not found in list. Reload List?" unless t

    st = Helper::login
    result = st.create_time_entry(t, info["start_time"],
      (Time.now - info["start_time"]).to_i)

    # Delete yml file
    if result
      FileUtils.rm(Helper::current_file)
    end                            

    # Output
    puts "Wrote new Entry for #{t.name}, duration #{result["duration_in_seconds"] / 60}m"
    return true
  end
     
end         
