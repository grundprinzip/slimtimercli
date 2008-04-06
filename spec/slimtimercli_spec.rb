require File.dirname(__FILE__) + '/spec_helper.rb'

# Time to add your specs!
# http://rspec.rubyforge.org/
describe "SlimTimer" do

  describe "Helper" do

    it "should return the path to the config files" do
      Slimtimercli::Helper::config_file.should =~ /.slimtimer\/config.yml/
      Slimtimercli::Helper::tasks_file.should =~ /.slimtimer\/tasks.yml/
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
      Slimtimercli::Helper.stub!(:root).and_return(File.dirname(__FILE__))
      
      @c = File.join(File.dirname(__FILE__), "current.yml")
      FileUtils.rm(@c) if File.exists?(@c)
      
      @d = File.join(File.dirname(__FILE__), "config.yml")
      FileUtils.rm(@d) if File.exists?(@d)
    end                         
                                                  
    it "should start a task" do
 
      # Manipulate ARGV
      Slimtimercli.start
      File.exists?(@c).should be_false
       
      # Set a task
      ARGV[1] = "test"
      Slimtimercli.start              
      File.exists?(@c).should be_true
                  
      # no double start                               
      Slimtimercli.start.should be_false
      
      
    end

    it "should stop a task" do
      Slimtimercli.stub!(:tasks).and_return(stub("task", :find => stub("task", :name => "test")))
      Slimtimercli::Helper.stub!(:login).
        and_return(stub("slimtimer", :create_time_entry => {"duration_in_seconds" => 10}))
      
      ARGV[1] = "test"
      Slimtimercli.start.should be_true
      Slimtimercli.end.should be_true
    end          
    
    it "should not stop a task if none is running" do
      Slimtimercli.end.should be_false
    end
    
  end

end