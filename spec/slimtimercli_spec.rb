require File.dirname(__FILE__) + '/spec_helper.rb'    

include Slimtimercli::Helper
# Time to add your specs!
# http://rspec.rubyforge.org/
describe "SlimTimer" do

  describe "Helper" do

    it "should return the path to the config files" do
      
      st = Slimtimercli::CommandLine.new(["-e"])
      
      st.config_file.should =~ /.slimtimer\/config.yml/
      st.tasks_file.should =~ /.slimtimer\/tasks.yml/
    end

  end

  describe "Entities" do

    describe "User" do

      it "should initialize correctly" do
        u = User.new("a", "b")
        u.email.should == "a"
        u.password.should == "b"
      end

      it "should load correctly from hash" do
        u = User._load({"email" => "a", "user_id" => "b", "name"  => "c"})
        u.email.should == "a"
        u.user_id.should == "b"
        u.name.should == "c"
      end

      it "should serialize correctly" do
        u = User.new("a", "b")
        u.user_id = 10
        r = u._serialize

        r.has_key?("user").should be_true
        r["user"]["email"].should == "a"
        r["user"]["password"].should == "b"
        r["user"].has_key?("user_id").should be_false

      end

    end

  end

  describe "command line interface" do
                         
    before  do
      Slimtimercli::CommandLine.
        any_instance.stubs(:root).returns(File.dirname(__FILE__))
      
      @c = File.join(File.dirname(__FILE__), "current.yml")
      FileUtils.rm(@c) if File.exists?(@c)
      
      @d = File.join(File.dirname(__FILE__), "config.yml")
      FileUtils.rm(@d) if File.exists?(@d)
      
    end                         
                                                  
    it "should start a task" do
      # Manipulate ARGV                     
      
      lambda { Slimtimercli::CommandLine.new([]) }.should
        raise_error(RuntimeError)
      File.exists?(@c).should be_false
      
      Slimtimercli::CommandLine.
        any_instance.stubs(:load_tasks).
        returns(stub("task", :find => stub("task", :name => "test")))   
        
      # Set a task
      ARGV[1] = "test"
      
      st = Slimtimercli::CommandLine.new(ARGV)
      st.start              
      File.exists?(@c).should be_true
                  
      # no double start                               
      st.start.should be_false
    end

    it "should stop a task" do
      Slimtimercli::CommandLine.
        any_instance.stubs(:load_tasks).
        returns(stub("task", :find => stub("task", :name => "test")))
        
      Slimtimercli::CommandLine.any_instance.stubs(:login).
        returns(stub("slimtimer", 
          :create_time_entry => {"duration_in_seconds" => 10}))
      
      ARGV[1] = "test"                         
      st = Slimtimercli::CommandLine.new(ARGV)
      st.start.should be_true
      st.end.should be_true
      
      File.exists?(@c).should be_false
    end          
    
    it "should not stop a task if none is running" do
      st = Slimtimercli::CommandLine.new(["-e"])
      st.end.should be_false
    end
    
    it "should not start a task that does not exist" do
      Slimtimercli::CommandLine.any_instance.
        stubs(:load_tasks).returns(stub("task", :find => nil))
      
      ARGV[1] = "not exisiting task"
      st = Slimtimercli::CommandLine.new(ARGV)
      st.start.should be_false     
      
    end
                                                   
    it "should allow to force the deletion of the current task" do
      st = Slimtimercli::CommandLine.new(["-e"])
      st.end.should be_false
      ARGV[0] = "-e"
      ARGV[1] = "--force" || "-f"              
      st = Slimtimercli::CommandLine.new(ARGV)
      st.end.should be_true
    end
    
  end

  describe "option parser" do
    
    it "should parse the start part correctly" do

      args = ["--start", "my_task"]
      options = parse(args)
      
      options.run.should == "start"
      options.task_name.should == "my_task"
      
    end
    
  end

end