Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root route
  root "home#index"
  
  # Rails applications (prepared for future implementation)
  get "amber" => "amber#index", as: :amber_path
  get "brgen" => "brgen#index", as: :brgen_path  
  get "privcam" => "privcam#index", as: :privcam_path
  get "bsdports" => "bsdports#index", as: :bsdports_path
  get "hjerterom" => "hjerterom#index", as: :hjerterom_path
  
  # Locale switching
  post "switch_locale" => "application#switch_locale", as: :switch_locale_path
  
  # Static pages (to be implemented)
  get "about" => "static#about", as: :about_path
  get "contact" => "static#contact", as: :contact_path
  get "careers" => "static#careers", as: :careers_path
  get "press" => "static#press", as: :press_path
  get "help" => "static#help", as: :help_path
  get "docs" => "static#docs", as: :docs_path
  get "api_docs" => "static#api_docs", as: :api_docs_path
  get "status" => "static#status", as: :status_path
  get "privacy" => "static#privacy", as: :privacy_path
  get "terms" => "static#terms", as: :terms_path
  get "gdpr" => "static#gdpr", as: :gdpr_path
  get "cookies" => "static#cookies", as: :cookies_path
  
  # AI3 routes
  get "ai3" => "ai3#index", as: :ai3_path
end
