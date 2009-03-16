module ActivityStepsHelper
  
  # def form_for_step(act_step)
  #   type = act_step.step_type
  #   # form_html = act.step.form_htm
  #   case type
  #   when 'Xhtml'
  #     act_step.step.name
  #   when 'MultipleChoice'
  #     act_step.step.prompt
  #   when 'OpenResponse'
  #     act_step.step.prompt
  #   end
  # end
  
  def html_for_step(act_step, mode="edit")
    @act_step = act_step
    @step = act_step.step
    type = act_step.step_type
    partial = "activity_steps/#{mode}_#{type.downcase}"
    html = "could not render partial (#{partial})"
    begin
      html = render(:partial => partial, :object => @act_step)
    rescue => e
      html = "#{html} : #{e}"
    end
    return html
  end

  def link_to_delete (act_step) 
    @word = 'word'
    @delete_step = act_step
    render(:partial => 'activity_steps/delete', :object => @act_step)
  end
  
  
end
