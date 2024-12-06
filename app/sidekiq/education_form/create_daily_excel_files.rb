# frozen_string_literal: true

require 'sentry_logging'
require 'sftp_writer/factory'

module EducationForm
  class DailyExcelFileError < StandardError
  end

  class CreateDailyExcelFiles
    MAX_RETRIES = 5
    STATSD_KEY = 'worker.education_benefits_claim'
    STATSD_FAILURE_METRIC = "#{STATSD_KEY}.failed_excel_file".freeze
    LIVE_FORM_TYPES = ['22-10282'].freeze
    AUTOMATED_DECISIONS_STATES = [nil, 'denied', 'processed'].freeze
    EXCEL_FIELDS = %w[
      name
      first_name
      last_name
      military_affiliation
      phone_number
      email_address
      country
      state
      race_ethnicity
      gender
      education_level
      employment_status
      salary
      technology_industry
    ].freeze
    HEADERS = ['Name', 'First Name', 'Last Name', 'Select Military Affiliation',
               'Phone Number', 'Email Address', 'Country', 'State', 'Race/Ethnicity',
               'Gender of Applicant', 'What is your highest level of education?',
               'Are you currently employed?', 'What is your current salary?',
               'Are you currently working in the technology industry? (If so, please select one)'].freeze
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options queue: 'default',
                    unique_for: 30.minutes,
                    retry: 5

    def perform
      retry_count = 0

      begin
        records = EducationBenefitsClaim
                  .unprocessed
                  .joins(:saved_claim)
                  .where(
                    saved_claims: {
                      form_id: LIVE_FORM_TYPES
                    }
                  )
        return false if federal_holiday?

        if records.count.zero?
          log_info('No records to process.')
          return true
        elsif retry_count.zero?
          log_info("Processing #{records.count} application(s)")
        end

        formatted_records = format_records(records)
        write_csv_file(formatted_records)
      rescue => e
        StatsD.increment("#{STATSD_FAILURE_METRIC}.general")
        if retry_count < MAX_RETRIES
          log_exception(DailySpoolFileError.new("Error creating excel files.\n\n#{e}
                                                 Retry count: #{retry_count}. Retrying..... "))
          retry_count += 1
          sleep(10 * retry_count) # exponential backoff for retries
          retry
        else
          log_exception(DailySpoolFileError.new("Error creating excel files.
                                                 Job failed after #{MAX_RETRIES} retries \n\n#{e}"))
        end
      end
      true
    end

    def write_csv_file(records)
      retry_count = 0

      begin
        @debug_records = records
        filename = "22-10282_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}.csv"

        CSV.open("tmp/#{filename}", 'wb') do |csv|
          # Add headers
          csv << HEADERS
          log_info('Successfully added headers')
          # Add data rows
          records.each_with_index do |record, index|
            log_info("Processing record #{index + 1}: #{record.inspect}")

            row_data = EXCEL_FIELDS.map do |field|
              value = record.public_send(field)
              value.is_a?(Hash) ? value.to_s : value
            end
            csv << row_data
          rescue => e
            log_exception(DailySpoolFileError.new("Failed to add row #{index + 1}: #{e.message}\nRecord: #{record.inspect}"))
            next
          end
        end

        log_info("Successfully added #{records.count} data rows")
        log_info('Successfully created CSV file')
      rescue => e
        StatsD.increment("#{STATSD_FAILURE_METRIC}.general")
        if retry_count < MAX_RETRIES
          log_exception(DailyExcelFileError.new('Error creating CSV files.'))
          log_exception(DailyExcelFileError.new("Retry count: #{retry_count}. Retrying..... "))
          retry_count += 1
          sleep(5)
          retry
        else
          log_exception(DailyExcelFileError.new("Error creating CSV files. Job failed after #{MAX_RETRIES} retries \n\n#{e}"))
        end
      end

      true
    end

    def format_records(records)
      records.map do |record|
        format_application(record)
      end.compact
    end

    def format_application(data)
      form = EducationForm::Forms::Base.build(data)
      track_form_type("22-#{data.form_type}")
      form
    rescue => e
      inform_on_error(data, e)
      nil
    end

    def inform_on_error(claim, error = nil)
      StatsD.increment("#{STATSD_KEY}.failed_formatting.22-#{claim.form_type}")
      exception = if error.present?
                    FormattingError.new("Could not format #{claim.confirmation_number}.\n\n#{error}")
                  else
                    FormattingError.new("Could not format #{claim.confirmation_number}")
                  end
      log_exception(exception)
    end

    private

    def federal_holiday?
      holiday = Holidays.on(Time.zone.today, :us, :observed)
      if holiday.empty?
        false
      else
        log_info("Skipping on a Holiday: #{holiday.first[:name]}")
        true
      end
    end

    def track_form_type(type)
      StatsD.gauge("#{STATSD_KEY}.transmissions.#{type}", 1)
    end

    def log_exception(exception)
      log_exception_to_sentry(exception)
    end

    def log_info(message)
      logger.info(message)
    end
  end
end
