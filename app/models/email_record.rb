# frozen_string_literal: true

class EmailRecord < ApplicationRecord
  # TODO: where is logging/statsD?
  # TODO: AASM or no?
  # TODO: create our own? has anyone done this?
  # TODO: breakout the service layer from the model (logging, api/external stuff)
  # TODO: polymorphic ID/active record association

  # What the original intent of the email was
  # Email notification of a failure
  # Email notification of a success
  # Email notification of other
  enum email_type: {
    success_type: 0,
    failure_type: 1,
    other: 2 # can be expanded later if needed
  }

  # States from downstream
  enum email_state: {
    delivered: 0,
    creating: 1,
    sending: 2,
    sent: 3,
    permanent_failure: 4,
    technical_failure: 5,
    temporary_failure: 6
  }

  END_FAILURE_STATES = %i[
    permanent_failure technical_failure temporary_failure
  ].freeze
  END_SUCCESS_STATES = [:delivered].freeze
  PENDING_STATES = %i[
    creating sending sent
  ].freeze

  def send_email(*, **)
    result = va_notify_service.send_email(*, **)
    self.va_notify_id = result.id
    save!
  end

  def get_va_notify_details
    va_notify_service.notify_client.get_notification(va_notify_id)
  end

  # Allows for finding email address through query service, do not need to store ourselves
  # IE Form526Submission.find(1234).email_records.failed.map(&:email_address)
  delegate :email_address, to: :get_va_notify_details

  def email_status
    get_va_notify_details.status
  end

  def update_va_notify_status!
    self.email_state = email_status.downcase.gsub('-', '_').to_sym
    save!
  end

  private

  def va_notify_service
    VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
  end
end
