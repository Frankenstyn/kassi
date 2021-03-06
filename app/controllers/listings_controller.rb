class ListingsController < ApplicationController
  
  before_filter :save_current_path, :only => :show
  before_filter :ensure_authorized_to_view, :only => :show

  before_filter :only => [ :new, :create ] do |controller|
    controller.ensure_logged_in(["you_must_log_in_to_create_new_#{params[:type]}", "create_one_here".to_sym, sign_up_path])
  end
  
  before_filter :only => [ :edit, :update, :close ] do |controller|
    controller.ensure_logged_in "you_must_log_in_to_view_this_content"
  end
  
  before_filter :only => [ :close ] do |controller|
    controller.ensure_current_user_is_listing_author "only_listing_author_can_close_a_listing"
  end
  
  before_filter :only => [ :edit, :update ] do |controller|
    controller.ensure_current_user_is_listing_author "only_listing_author_can_edit_a_listing"
  end
  
  def index
    redirect_to root
  end
  
  def requests
    params[:listing_type] = "request"
    @to_render = {:action => :index}
    @listings_per_page = 5
    @listings = Listing.requests.visible_to(@current_user, @current_community).open.paginate(:per_page => @listings_per_page, :page => params[:page], :order => "created_at DESC")
    load
  end
  
  def offers
    params[:listing_type] = "offer"
    @to_render = {:action => :index}
    @listings_per_page = 5
    @listings = Listing.offers.visible_to(@current_user, @current_community).open.paginate(:per_page => @listings_per_page, :page => params[:page], :order => "created_at DESC")
    load
  end
  
  # Used to load listings to be shown
  # How the results are rendered depends on 
  # the type of request and if @to_render is set
  def load
    #print(params)
    @title = params[:listing_type]
    @to_render ||= "load"
    @listings = Listing.open.order("created_at DESC").find_with(params, @current_user, @current_community).paginate(:per_page => 5, :page => params[:page])
    render @to_render
#    @request_path = request.fullpath
#
#    if request.xhr? && params[:page] && params[:page].to_i > 1
#      render :partial => "listings/additional_listings"
#    else
#      render @to_render
#    end
  end
  
  def show
    params[:listing_type] = @listing.listing_type
    @listing.increment!(:times_viewed)
  end
  
  def new
    @listing = Listing.new
    params[:listing_type] = params[:type]
    @listing.listing_type = params[:type]
    @listing.category = params[:category] || "housing"
    1.times { @listing.listing_images.build }
    respond_to do |format|
      format.html
      format.js {render :layout => false}
    end
  end
  
  def create
    @form_title = params[:listing][:title]
    @form_description = params[:listing][:description]
    
    if @form_title.blank?
      flash[:error] = "Title field is required"
      redirect_to :back
      return
    elsif @form_title.length < 2
      flash[:error] = "Title field is too short"
      redirect_to :back
      return
    end
    
    @listing = @current_user.create_listing params[:listing]
    if @listing.new_record?
      1.times { @listing.listing_images.build } if @listing.listing_images.empty?
      render :action => :new
    else
      path = new_request_category_path(:type => @listing.listing_type, :category => @listing.category)
      flash[:notice] = ["#{@listing.listing_type}_created_successfully", "create_new_#{@listing.listing_type}".to_sym, path]
      Delayed::Job.enqueue(ListingCreatedJob.new(@listing.id, request.host))
      redirect_to @listing
    end
  end
  
  def edit
    @subcategory = ShareType.find_by_listing_id @listing.id   
    1.times { @listing.listing_images.build } if @listing.listing_images.empty?
  end
  
  def update
    if @listing.update_fields(params[:listing])
      flash[:notice] = "#{@listing.listing_type}_updated_successfully"
      redirect_to @listing
    else
      render :action => :edit
    end    
  end
  
  def close
    @listing.update_attribute(:open, false)
    flash.now[:notice] = "#{@listing.listing_type} closed"
    respond_to do |format|
      format.html { redirect_to @listing }
      format.js { render :layout => false }
    end
  end
  
  #shows a random listing from current community
  def random
    open_listings_ids = Listing.open.select("id").find_with(nil, @current_user, @current_community).all
    if open_listings_ids.empty?
      redirect_to root and return
      #render :action => :index and return
    end
    random_id = open_listings_ids[Kernel.rand(open_listings_ids.length)].id
    #redirect_to listing_path(random_id)
    @listing = Listing.find_by_id(random_id)
    render :action => :show
  end
  
  def ensure_current_user_is_listing_author(error_message)
    @listing = Listing.find(params[:id])
    return if current_user?(@listing.author) || @current_user.is_admin?
    flash[:error] = error_message
    redirect_to @listing and return
  end
  
  private
  
  # Ensure that only users with appropriate visibility settings can view the listing
  def ensure_authorized_to_view
    @listing = Listing.find(params[:id])
    if @current_user
      unless @listing.visible_to?(@current_user, @current_community)
        flash[:error] = "you_are_not_authorized_to_view_this_content"
        redirect_to root and return
      end
    else
      unless @listing.visibility.eql?("everybody")
        session[:return_to] = request.fullpath
        flash[:warning] = "you_must_log_in_to_view_this_content"
        redirect_to new_session_path and return
      end
    end
  end
  
  def showimage
    
  end

end
