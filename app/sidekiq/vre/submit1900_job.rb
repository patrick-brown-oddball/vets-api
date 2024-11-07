# frozen_string_literal: true

require 'vre/monitor'

module VRE
  class Submit1900Job
    include Sidekiq::Job
    include SentryLogging

    STATSD_KEY_PREFIX = 'worker.vre.submit_1900_job'
    RETRY = 14

    sidekiq_options retry: RETRY

    sidekiq_retries_exhausted do |msg, _ex|
      claim_id, encrypted_user = msg['args']
      Rails.logger.warn("VRE::Submit1900Job failed, sending to Benefits Intake API: #{e.message}", {
                          message: msg['error_message'],
                          saved_claim_id: claim_id
                        })
      VRE::BenefitsIntakeSubmit1900Job.perform_async(claim_id, encrypted_user)
    end

    def perform(claim_id, encrypted_user)
      email_addr = REGIONAL_OFFICE_EMAILS[@office_location] || 'VRE.VBACO@va.gov'
      Rails.logger.info('VRE claim sending email:', { email: email_addr, user_uuid: user.uuid })
      VeteranReadinessEmploymentMailer.build(user.participant_id, email_addr,
                                             @sent_to_lighthouse).deliver_later

      claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
      user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      claim.send_to_vre(user)
      if Flipper.enabled?(:veteran_readiness_employment_to_res)
        send_to_res(user)
      else
        send_vre_form(user)
      end
    rescue => e
      Rails.logger.warn("VRE::Submit1900Job failed, retrying...: #{e.message}")
      raise
    end

    def self.trigger_failure_events(msg)
      claim_id, encrypted_user = msg['args']
      claim = SavedClaim.find(claim_id)
      user = OpenStruct.new(JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_user)))
      email = claim.parsed_form['email'] || user['va_profile_email']
      VANotify::EmailJob.perform_async(
        email,
        Settings.vanotify.services.va_gov.template_id.form1900_action_needed_email,
        {
          'first_name' => claim.parsed_form.dig('veteranInformation', 'fullName', 'first'),
          'date' => Time.zone.today.strftime('%B %d, %Y'),
          'confirmation_number' => claim.confirmation_number
        }
      )
    end
  end
end
