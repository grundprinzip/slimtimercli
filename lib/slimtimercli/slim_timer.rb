class SlimTimer

  DATE_FORMAT = "%Y-%m-%d %H-%M-%S"

  @@host = "slimtimer.com"
  @@port = 80
  #@@api_key = ""

  attr_accessor :tasks, :time_entries

  def initialize(user, pass, api)
    @user = user; @pass = pass
    @api_key = api
  end

  # Performs the login to the system, and stores
  # the user id and the access token in the local
  # class for reusse
  def login
    data = post_request("/users/token", User.new(@user, @pass)._serialize)
    @token = data["access_token"]
    @user_id = data["user_id"]
  end

  # Lists all tasks for the user logged in the system
  # ==== Parameters
  # show_completed<String>:: yes | no | only Include completed tasks (yes/no)
  #                          or show only completed tasks Default: yes
  # role<String>:: owner,coworker,reporter Include tasks where the user's role
  #                is one of the roles given (comma delimited) Default:
  #                 owner,coworker
  def tasks(show_completed = "yes", role="owner,coworker")
    list = get_request("/users/#{@user_id}/tasks",
      {"show_completed" => show_completed,
        "role" => role})

    list.map{ |t|
        Task._load(t)
      }

  end

  # Create a new task for this user
  # ==== Parameters
  # name<String>:: name for the new task
  # tags<String>:: comma separated list of tags for the task
  def create_task(name, tags= "", coworker_emails = "", reporter_emails = "")

    t = Task.new
    t.name = name
    t.tags = tags

    t._serialize


    Task._load(post_request("/users/#{@user_id}/tasks", t._serialize))
  end

  def find_task_by_name(name)
    tasks("no").find {|t| t.name == name}
  end

  def delete_task(name)
    t = find_task_by_name(name)
    delete_request("/users/#{@user_id}/tasks/#{t.id}")
  end

  # List all time entries for the user logged in
  # ==== Parameters
  # range_start<Time>:: start of the range
  # range_end<Time>:: end of the range
  def time_entries(range_start = nil, range_end = nil)
    options = {}

    options = {"range_start" =>
      range_start.strftime(DATE_FORMAT)} if range_start
    options = {"range_end" =>
      range_end.strftime(DATE_FORMAT)} if range_end

    # do the actual request
    get_request("/users/#{@user_id}/time_entries", options)
  end

  def create_time_entry(task, start_time = Time.now, duration = 0)
    te = TimeEntry.new
    te.task = task; te.start_time = start_time
    te.duration_in_seconds = duration
    
    post_request("/users/#{@user_id}/time_entries", te._serialize)
  end

  protected

  def handle_error(object)
    if object.kind_of?(ActiveRecord::Errors)
      raise "ActiveRecord::Errors " + object.map{|k,v| k + " " + v}.join("\n")
    else
      object
    end
  end

  def get_request(path, params = {})
    post_request(path, {"_method" => "get"}.merge(params))
  end

  def put_request(path, params = {})
    post_request(path, {"_method" => "put"}.merge(params))
  end

  def delete_request(path, params = {})
    post_request(path, {"_method" => "delete"}.merge(params))
  end

  def post_request(path, params = {})
    request(Net::HTTP::Post.new(path, default_header), params)
  end

  def request(method, params = {})
    
    puts "Start Request" if $DEBUG
    # merge api key
    params = {"api_key" => @api_key}.merge(params)
    # If token there merge it
    params = {"access_token" => @token}.merge(params) if @token
    res, body = Net::HTTP.start(@@host,@@port) {|http|     
          p params if $DEBUG
          method.body = params.to_yaml
          http.request(method)
        }              
    puts "Finished Request" if $DEBUG
    handle_error(YAML.load(body))
  end

  def default_header
    {"Accept" => "application/x-yaml",
      "Content-Type" => "application/x-yaml"}
  end

end
