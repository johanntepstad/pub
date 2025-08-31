
# encoding: utf-8
# Manages user-specific context for maintaining conversation state

class ContextManager
  def initialize(weaviate_helper)
    @contexts = {}
    @weaviate_helper = weaviate_helper
  end

  def update_context(user_id:, text:)
    @contexts[user_id] ||= []
    @contexts[user_id] << text
    @weaviate_helper.save_context(user_id: user_id, text: text)
    trim_context(user_id) if @contexts[user_id].join(' ').length > 4096
  end

  def get_context(user_id:)
    @contexts[user_id] || []
  end

  private

  def trim_context(user_id)
    context_text = @contexts[user_id].join(' ')
    while context_text.length > 4096
      @contexts[user_id].shift
      context_text = @contexts[user_id].join(' ')
    end
  end

  def log_error(message)
    puts "[ERROR] #{message}"
  end
end
