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
  
  
end