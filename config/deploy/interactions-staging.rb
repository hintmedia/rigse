# interactions staging branch
set :user, "deploy"
set :domain, "interactions.staging.concord.org"
set :deploy_to, "/web/portal"
server domain, :app, :web
role :db, domain, :primary => true
set :branch, "topic_np_image_gallery_from_itsisu"
