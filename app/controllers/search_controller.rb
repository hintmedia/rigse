class SearchController < ApplicationController

  in_place_edit_for :investigation, :search_term
  
  def index
    unless current_user.portal_teacher || current_user.anonymous?
      redirect_to root_path
      return
    end
    flash[:notice] = nil
    search_options=get_searchoptions()
    @investigations_count=0
    @activities_count=0
    if @material_type.include?('investigation')
      @investigations = Investigation.search_list(search_options)
      @investigations_count = @investigations.length
      @investigations = @investigations.paginate(:page => params[:investigation_page]? params[:investigation_page] : 1, :per_page => 10) 
    end
    if @material_type.include?('activity')
      @activities = Activity.search_list(search_options)
      @activities_count = @activities.length
      @activities = @activities.paginate(:page => params[:activity_page]? params[:activity_page] : 1, :per_page => 10)
    end
  end
  
  def show
    unless current_user.portal_teacher || current_user.anonymous?
      redirect_to root_path
      return
    end
    flash[:notice] = nil
    @investigations_count=0
    @activities_count=0
    search_options=get_searchoptions()
    if @material_type.include?('investigation')
      investigations = Investigation.search_list(search_options)
      @investigations_count = investigations.length
      investigations = investigations.paginate(:page => params[:activity_page]? params[:activity_page] : 1, :per_page => 10)
    end
    if @material_type.include?('activity')
      activities = Activity.search_list(search_options)
      @activities_count = activities.length
      activities = activities.paginate(:page => params[:activity_page]? params[:activity_page] : 1, :per_page => 10)
    end  
    if request.xhr?
      render :update do |page| 
        page.replace_html 'offering_list', :partial => 'search/search_results',:locals=>{:investigations=>investigations,:activities=>activities}
        page << "$('suggestions').remove();"
      end
    else
      respond_to do |format|
        format.html do
            render 'index'
        end
        format.js
      end
    end
  end
  
  def get_searchoptions
    @search_term = params[:search_term]
    @sort_order = param_find(:sort_order, (params[:method] == :get)) || 'name ASC'
    @domain_id = param_find(:domain_id, (params[:method] == :get)) || []
    @grade_span = param_find(:grade_span, (params[:method] == :get)) || []
    @investigation_page=params[:investigation_page]|| 1
    @activity_page = params[:activity_page] || 1
    @material_type = param_find(:material, (params[:method] == :get)) || ['investigation','activity']
    search_options = {
      :name => @search_term || '',
      :sort_order => @sort_order,
      :domain_id => @domain_id || [],
      :grade_span => @grade_span|| [],
      :paginate => false
      #:page => params[:investigation_page] ? params[:investigation_page] : 1,
      #:per_page => 10
    }
    return search_options
  end
  
  def get_search_suggestions
    @search_term = params[:search_term]
    search_options = {
      :name => @search_term,
      :sort_order => 'name ASC'
    }
    
    investigations = Investigation.search_list(search_options)
    activities = Activity.search_list(search_options)
    @suggestions= [];
    @suggestions = investigations + activities
    if request.xhr?
       render :update do |page|
         page.replace_html 'search_suggestions', {:partial => 'search/search_suggestions',:locals=>{:textlength=>@search_term.length,:investigations=>investigations,:activities=>activities}}
       end
    end
  end
  
  def get_current_material_unassigned_clazzes
    material_type = params[:material_type]
    if material_type == "Investigation"
      material = ::Investigation.find(params[:material_id])
    elsif material_type == "Activity"
      material = ::Activity.find(params[:material_id])
    end
  
    teacher_clazzes = current_user.portal_teacher.teacher_clazzes
    teacher_clazz_ids = teacher_clazzes.map{|item| item.clazz_id}
    teacher_offerings = Portal::Offering.where(:runnable_id=>params[:material_id], :runnable_type=>params[:material_type], :clazz_id=>teacher_clazz_ids)
    assigned_clazz_ids = teacher_offerings.map{|item| item.clazz_id}
    unassigned_teacher_clazzes = teacher_clazzes.select{|item| assigned_clazz_ids.index(item.clazz_id).nil?}
    unassigned_clazzes = Portal::Clazz.where(:id=>unassigned_teacher_clazzes.map{|item| item.clazz_id})
    render :partial => 'material_unassigned_clazzes', :locals => {:material=>material,:clazzes=>unassigned_clazzes}
  end
  
  def add_material_to_clazzes
    clazz_ids = params[:clazz_id]
    runnable_id = params[:material_id].to_i
    runnable_type = params[:material_type].classify
    clazz_ids.each do|clazz_id|
      portal_clazz = Portal::Clazz.find(clazz_id)
      offering = Portal::Offering.find_or_create_by_clazz_id_and_runnable_type_and_runnable_id(portal_clazz.id,runnable_type,runnable_id)
      if offering.position == 0
        offering.position = portal_clazz.offerings.length
        offering.save
      end
    end
    
    if runnable_type == "Investigation"
      material = ::Investigation.find(runnable_id)
    elsif runnable_type == "Activity"
      material = ::Activity.find(runnable_id)
    end
    
    if request.xhr?
       render :update do |page|
         page << "alert('#{runnable_type} is assigned to the selected class(es) successfully.')"
         page << "close_popup()"
         page.replace_html "search_#{runnable_type.downcase}_#{runnable_id}", {:partial => 'result_item', :locals=>{:material=>material}}
       end
    end
  end
  
end
