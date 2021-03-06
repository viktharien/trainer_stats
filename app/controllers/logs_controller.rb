class LogsController < ApplicationController
    
    before_action :set_log, only: [:show, :edit, :destroy]
    before_action :total_trainings, only: [:index, :inactive]
    before_action :authenticate_user!, except: [:index, :show, :search]
    
    def search
        @trainings = {}
        @logs = Log.all
        @users = User.all
        @url = request.fullpath.to_s.split("?")[1]
        @results = 0
        @disallow_multi = false
        
        @logs.each do |log|
            
            log.trainings.each do |t|
                @training_attrs = {}
                t.attributes.each do |name, value|
                    if name == "created_at"
                        @training_attrs[name] = value.in_time_zone("Central Time (US & Canada)").strftime("%m/%d/%Y at %I:%M %p")
                    else
                        @training_attrs[name] = value.to_s
                    end
                end
                
                if params[:query] == "date"
                    @new_params = params
                    @string = @new_params[:string].split("_")
                    @new_params["from_date"] = @string[0]
                    @new_params["to_date"] = @string[1]
                    
                    @disallow_multi = true
                    if params[:status] || params[:stage]  || params[:trainer]
                        @trainings[t.id] = {:info => @training_attrs} if date_compare(t, @new_params["from_date"], @new_params["to_date"]) && multi_param_compare(params.stringify_keys, @training_attrs, true)
                    else
                        @trainings[t.id] = {:info => @training_attrs} if date_compare(t, @new_params["from_date"], @new_params["to_date"])
                    end
                else
                
                    if params[:status] || params[:stage]  || params[:trainer]
                        @trainings[t.id] = {:info => @training_attrs} if search_compare(@training_attrs[params[:query]],params[:string]) && multi_param_compare(params.stringify_keys, @training_attrs)
                    else
                        @trainings[t.id] = {:info => @training_attrs} if search_compare(@training_attrs[params[:query]],params[:string])
                    end
                
                end
                
            end
            
        end
        @title = "Search"
    end
    
    def index
        @logs = Log.where(active: true).order('id DESC')
        @active = @logs.count
        @total = Log.all.count
        respond_to do |format|
            format.html
            format.json { json_response(@all_logs)}
        end
        @title = "Trainings Logs"
    end
    
    def inactive
        @logs = Log.where(active: false).order('id DESC')
        @inactive = @logs.count
        @total = Log.all.count
        
        respond_to do |format|
            format.html
            format.json { json_response(@all_logs)}
        end
        @title = "Inactive Trainings Logs"
    end
    
    def show
        @users = User.all
        if params[:sort]
            @trainings = @log.trainings.where(trainer: params[:sort]).order('id DESC')
        else
            @trainings = @log.trainings.order('id DESC')
        end
        @count = @trainings.count
        
        respond_to do |format|
            format.html
            format.json { 
                    json_response(@log.to_json(:include => [:trainings]))  
            }
            format.csv { send_data @trainings.to_csv, filename: "#{@log.title}.csv" }
            format.xls { send_data @trainings.to_csv(col_sep: "\t"), filename: "#{@log.title}.xls" }
        end
        @title = "#{@log.title}"
        
    end
    
    def new
       @log = Log.new
       @title = "New Trainings Log"
    end
    
    def create
        @log = Log.new(params_log)
        if @log.save
            create_event("created", "log with ID: #{@log.id}, Title: #{@log.title}")
            redirect_to @log
        else
            render 'new'
        end
    end
    
    def edit
        @title = "Edit Trainings Log"
    end
    
    def update
        
        @log = Log.find(params[:id])
        @old_title = @log.title
        if @log.update(params_log)
            create_event("updated", "log with ID: #{@log.id}, Title: #{@old_title} to (Title: #{@log.title}, Active: #{@log.active})")
            redirect_to logs_path
        else
            render 'edit'
        end
    end
    
    def destroy
        create_event("destroyed", "log with ID: #{@log.id}, Title: #{@log.title}")
        @log.destroy
        redirect_to logs_path
        
    end
    
    private
    
        def set_log
           if Log.where(id: params[:id]).exists?
               @log = Log.find(params[:id])
           else
               not_found
               
           end
        end
        
        def params_log
            params.require(:log).permit(:title, :active) 
        end
        
        def all_trainings(logs)
            training_arr = []
            logs.each do |l|
                 training_arr.push(l.trainings.count)
            end
            training_arr.reduce(&:+)
        end
        
        def total_trainings
            @all_logs = Log.all
            @total_trainings = all_trainings(@all_logs)
        end
        
        
end
