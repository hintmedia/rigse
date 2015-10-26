class Dataservice::BucketContentsMetalController < ActionController::Metal

  def create
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHECK_AUTHORIZE
    authorize Dataservice::BucketContentsMetal
    create_with_logger(Dataservice::BucketLogger.find(params[:id]))
  end

  def create_by_learner
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize Dataservice::BucketContentsMetal
    # authorize @bucket_contents_metal
    # authorize Dataservice::BucketContentsMetal, :new_or_create?
    # authorize @bucket_contents_metal, :update_edit_or_destroy?
    learner = Portal::Learner.find(params[:id]) rescue nil
    bucket_logger = learner ? Dataservice::BucketLogger.find_or_create_by_learner_id(learner.id) : nil
    create_with_logger(bucket_logger)
  end

  def create_by_name
    # PUNDIT_REVIEW_AUTHORIZE
    # PUNDIT_CHOOSE_AUTHORIZE
    # no authorization needed ...
    # authorize Dataservice::BucketContentsMetal
    # authorize @bucket_contents_metal
    # authorize Dataservice::BucketContentsMetal, :new_or_create?
    # authorize @bucket_contents_metal, :update_edit_or_destroy?
    bucket_logger = Dataservice::BucketLogger.find_or_create_by_name(params[:name])
    create_with_logger(bucket_logger)
  end

  private

  def create_with_logger(bucket_logger)
    bucket_content = nil
    if bucket_logger
      body = request.body.read
      # also set processed and empty for now
      bucket_content = Dataservice::BucketContent.create(
        :bucket_logger_id => bucket_logger.id,
        :body => body,
        :processed => true,
        :empty => (body.nil? || body.empty?)
      )
    end
    if bucket_content
      digest = Digest::MD5.hexdigest(body)

      self.status = 201
      self.content_type = 'text/xml'
      self.response_body = ''
      self.headers['Last-Modified'] = bucket_content.created_at.httpdate
      self.headers['Content-Length'] = '0'
      self.headers['Content-MD5'] = digest
    else
      self.status = 404
      self.content_type = 'text/html'
      self.response_body = 'Not Found'
    end
  end

end
