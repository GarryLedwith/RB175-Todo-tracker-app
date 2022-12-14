require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do 
  enable :sessions 
  set :session_secret, 'secret'
end

configure do 
  set :erb, :escape_html => true 
end 

helpers do 
  def is_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0 
  end

  def list_class(list)
    "complete" if is_complete?(list)
  end

  def todos_count(list)
    list[:todos].size 
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size 
  end 

  def sort_lists(lists, &block)
    incomplete_lists = {}
    complete_lists = {}

    lists.each_with_index do |list, index|
      if is_complete?(list)
        complete_lists[list] = index
      else 
        incomplete_lists[list] = index
      end 
    end
    incomplete_lists.each(&block)
    complete_lists.each(&block) 
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    todos.each_with_index do |todo, index|
      if todo[:completed] 
        complete_todos[todo] = index
      else 
        incomplete_todos[todo] = index
      end 
    end
    incomplete_todos.each(&block)
    complete_todos.each(&block) 
  end
end

def load_list(index) # need to circle back and break this method down 
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

before do 
  session[:lists] ||= []
end

get "/" do 
  redirect "/lists"
end 

# View all lists 
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout 
end

# Render the new list form 
get "/lists/new" do 
 erb :new_list, layout: :layout
end

# Return an error message if the name is invalid, else return nil 
def error_for_list_name(name)
  if !(1..100).cover?(name.size)  
     "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
     "List name must be unique."
  end 
end

# Return an error message if the name is invalid, else return nil 
def error_for_todo(name)
  if !(1..100).cover?(name.size)  
     "Todo must be between 1 and 100 characters."
  end 
end

# Create a new list 
post "/lists" do 
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error 
    session[:error] = error
    erb :new_list, layout: :layout
  else 
    session[:lists] << {name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# View a single todo list  
get "/lists/:id" do 
  @list_id = params[:id].to_i
  # @list = session[:lists][@list_id]
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do 
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Update existing todo list 
post "/lists/:id" do # Need to circle back and write a detailed process of this method in my notes 
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(@list_id)
  
  error = error_for_list_name(list_name)
  if error 
    session[:error] = error
    erb :edit_list, layout: :layout
  else 
    @list[:name] = list_name
    session[:success] = "The list has been created."
    redirect "/lists/#{id}"
  end
end

# Delete a todo list 
post "/lists/:id/delete" do 
  id = params[:id].to_i 
  session[:lists].delete_at(id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo to the list 
post "/lists/:list_id/todos" do 
  @list_id = params[:list_id].to_i 
  @list = load_list(@list_id)
  text = params[:todo].strip 

  error = error_for_todo(text)
  if error 
    session[:error] = error
    erb :list, layout: :layout
  else 
    @list[:todos] << {name: text, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"  
  end
end

# Delete a todo from a list 
# I want to use JavaScript here before this action is executed 
post "/lists/:list_id/todos/:id/delete" do 
  @list_id = params[:list_id].to_i 
  @list = load_list(@list_id)

  todo_id = params[:id].to_i 
  @list[:todos].delete_at(todo_id)
  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_id}"
end

# Update the status of a todo 
post "/lists/:list_id/todos/:id" do 
  @list_id = params[:list_id].to_i 
  @list = load_list(@list_id)

  todo_id = params[:id].to_i 
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end 

# Mark all todos as complete for a list 
post "/lists/:id/complete_all" do 
  @list_id = params[:id].to_i 
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = true 
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end


