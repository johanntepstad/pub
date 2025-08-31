
# encoding: utf-8
# Prompt manager for handling dynamic prompt generation

class PromptManager
  def initialize(templates)
    @templates = templates
  end

  def generate_prompt(template_name, context, *args)
    template = @templates.fetch(template_name)
    filled_template = template % { context: context, args: args }
    filled_template
  end

  def add_template(template_name, template)
    @templates[template_name] = template
  end
end
