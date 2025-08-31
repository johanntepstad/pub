
# encoding: utf-8
# Feedback manager for handling user feedback and improving services

require_relative 'error_handling'
require_relative 'weaviate_helper'

class FeedbackManager
  def initialize(weaviate_helper)
    @weaviate_helper = weaviate_helper
  end

  def record_feedback(user_id, query, feedback)
    with_error_handling do
      feedback_data = {
        'user_id': user_id,
        'query': query,
        'feedback': feedback
      }
      @weaviate_helper.save_context(user_id: user_id, text: feedback)
    end
  rescue => e
    ErrorHandler.handle(e, context: { user_id: user_id, query: query, feedback: feedback })
  end

  def retrieve_feedback(user_id)
    @weaviate_helper.search_vector("feedback from user #{user_id}")
  rescue => e
    ErrorHandler.handle(e, context: { user_id: user_id })
    []
  end
end
