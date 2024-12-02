# frozen_string_literal: true

module IvcChampva
  class Email
    attr_reader :data

    EMAIL_TEMPLATE_MAP = {
      '10-10D' => Settings.vanotify.services.ivc_champva.template_id.form_10_10d_email,
      '10-10D-FAILURE' => Settings.vanotify.services.ivc_champva.template_id.form_10_10d_failure_email,
      '10-7959F-1' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959f_1_email,
      '10-7959F-1-FAILURE' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959f_1_failure_email,
      '10-7959F-2' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959f_2_email,
      '10-7959F-2-FAILURE' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959f_2_failure_email,
      '10-7959C' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959c_email,
      '10-7959C-FAILURE' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959c_failure_email,
      '10-7959A' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959a_email,
      '10-7959A-FAILURE' => Settings.vanotify.services.ivc_champva.template_id.form_10_7959a_failure_email
    }.freeze

    def initialize(data)
      @data = data
    end

    def send_email
      Datadog::Tracing.trace('Send PEGA Status Update Email') do
        return false unless valid_environment?

        VANotify::EmailJob.perform_async(
          data[:email],
          (data[:template_id] ? EMAIL_TEMPLATE_MAP[data[:template_id]] : EMAIL_TEMPLATE_MAP[data[:form_number]]),
          {
            'first_name' => data[:first_name],
            'last_name' => data[:last_name],
            'file_count' => data[:file_count],
            'pega_status' => data[:pega_status],
            'date_submitted' => data[:created_at]
          },
          Settings.vanotify.services.ivc_champva.api_key
        )
        true
      rescue => e
        Rails.logger.error "Pega Status Update Email Error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end

    private

    def valid_environment?
      %w[production staging].include?(Rails.env)
    end
  end
end
