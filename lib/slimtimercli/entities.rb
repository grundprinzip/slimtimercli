class TimeEntry
  attr_accessor :id, :start_time, :end_time,
    :duration_in_seconds, :tags, :in_progress, :updated_at,
    :created_at, :task

  def self._load(hsh)
    te = TimeEntry.new
    hsh.each {|k,v|
        te.__send__("#{k}=".to_sym, v) if te.respond_to?("#{k}=".to_sym)
      }
  end 
  
  def _serialize
    {"time_entry" =>  {
      "start_time" => @start_time,
      "duration_in_seconds" => @duration_in_seconds,
      "task_id" => @task.id}}
  end

end

class Task
  attr_accessor :name, :tags, :role, :owners, :hours,
    :id

  def self._load(hsh)
    Task.new.__send__(:_load, hsh)
  end

  def _serialize
    {"task" => instance_variables.map{ |i|
        {i.to_s.gsub("@", "") => instance_variable_get(i)}
       }.inject({}){|m,v| m.merge v}}
  end

  private

  def _load(hsh)
    hsh.each do |k,v|
      self.instance_variable_set("@#{k}", v) if self.respond_to?(k.to_sym) &&
        !v.kind_of?(Array)
    end

    @owners = hsh["owners"].map{|o| User._load(o)}
    @coworkers = hsh["coworkers"].map{|o| User._load(o)}

    self
  end

end

class User
  attr_accessor :email, :password, :user_id, :name

  def initialize(e=nil, p=nil)
    @email = e
    @password = p
  end

  def self._load(hsh)
    u = User.new
    hsh.each do |k,v|
      u.send("#{k}=".to_sym, v) if u.respond_to?("#{k}=".to_sym)
    end
    u
  end

  def _serialize
    {"user" => {"email" => email, "password" => password}}
  end
end
