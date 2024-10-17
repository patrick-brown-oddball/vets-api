# frozen_string_literal: true

require 'benefits_intake_service/service'

class Form526StatusPollingJob < BenefitsIntakeStatusPollingJob

  private

  def submissions
    @submissions ||= Form526Submission.pending_backup
  end

  def handle_response(response)
    response.body['data']&.each do |submission|
      status = submission.dig('attributes', 'status')
      form_submission = Form526Submission.find_by(backup_submitted_claim_id: submission['id'])

      handle_submission(status, form_submission)
      @total_handled += 1
    end
  end

  def handle_submission(status, form_submission)
    if %w[error expired].include? status
      log_result('failure')
      form_submission.rejected!
    elsif status == 'vbms'
      log_result('true_success')
      form_submission.accepted!
    elsif status == 'success'
      log_result('paranoid_success')
      form_submission.paranoid_success!
    else
      Rails.logger.info(
        'Unknown or incomplete status returned from Benefits Intake API for 526 submission',
        status:,
        submission_id: form_submission.id
      )
    end
  end

  def log_result(result)
    StatsD.increment("#{STATS_KEY}.submission_status.526.#{result}")
    StatsD.increment("#{STATS_KEY}.submission_status.all_forms.#{result}")
  end
end
