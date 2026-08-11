Rails.application.routes.draw do
 namespace :api do
  namespace :v1 do
   post 'rewrite', to: 'rewrites#create'
  end
 end
end
