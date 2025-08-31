class HomeController < ApplicationController
  def index
    @apps = [
      {
        name: 'amber',
        title: 'Amber - Fashion & Style',
        description: 'Fashion and style management application',
        path: '/amber',
        icon: '👗'
      },
      {
        name: 'brgen',
        title: 'Brgen - Social Platform',
        description: 'Social features and content generation',
        path: '/brgen',
        icon: '🤝'
      },
      {
        name: 'privcam',
        title: 'PrivCam - Privacy Camera',
        description: 'Privacy-focused camera application',
        path: '/privcam',
        icon: '📷'
      },
      {
        name: 'bsdports',
        title: 'BSD Ports - Package Management',
        description: 'BSD ports management system',
        path: '/bsdports',
        icon: '📦'
      },
      {
        name: 'hjerterom',
        title: 'Hjerterom - Personal Wellness',
        description: 'Personal spaces and wellness management',
        path: '/hjerterom',
        icon: '💖'
      }
    ]
  end
end