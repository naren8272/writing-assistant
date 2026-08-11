module Api; module V1; class RewritesController < ActionController::API
 def create
  text=params[:text].to_s.strip
  return render json:{error:'text is required'},status:422 if text.empty?
  render json:{suggestions:RewriteText.new(text:text).call}
 rescue => e
  Rails.logger.error("rewrite_failed=#{e.class}: #{e.message}")
  render json:{error:'rewrite failed'},status:502
 end
end; end; end
