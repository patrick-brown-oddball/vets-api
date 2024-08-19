# frozen_string_literal: true

module Vye
  class UserProfileConflict < StandardError; end
  class UserProfileNotFound < StandardError; end

  class LoadData
    STATSD_PREFIX = name.gsub('::', '.').underscore
    STATSD_NAMES =
      {
        failure: "#{STATSD_PREFIX}.failure.no_source",
        team_sensitive_failure: "#{STATSD_PREFIX}.failure.team_sensitive",
        tims_feed_failure: "#{STATSD_PREFIX}.failure.tims_feed",
        bdn_feed_failure: "#{STATSD_PREFIX}.failure.bdn_feed",
        user_profile_created: "#{STATSD_PREFIX}.user_profile.created",
        user_profile_updated: "#{STATSD_PREFIX}.user_profile.updated"
      }.freeze

    SOURCES = %i[team_sensitive tims_feed bdn_feed].freeze

    FAILURE_TEMPLATE = <<~FAILURE_TEMPLATE_HEREDOC.gsub(/\n/, ' ').freeze
      Loading data failed:
      source: %<source>s,
      locator: %<locator>s,
      error message: %<error_message>s
    FAILURE_TEMPLATE_HEREDOC

    private_constant :SOURCES

    private

    attr_reader :bdn_clone, :locator, :user_profile, :user_info, :source

    def initialize(source:, locator:, bdn_clone: nil, records: {})
      raise ArgumentError, format('Invalid source: %<source>s', source:) unless sources.include?(source)
      raise ArgumentError, 'Missing locator' if locator.blank?
      raise ArgumentError, 'Missing bdn_clone' unless source == :tims_feed || bdn_clone.present?

      @bdn_clone = bdn_clone
      @locator = locator
      @source = source

      UserProfile.transaction do
        @valid_flag = send(source, **records)
      end
    rescue => e
      format(FAILURE_TEMPLATE, source:, locator:, error_message: e.message).tap do |msg|
        Rails.logger.error(msg)
      end
      (sources.include?(source) ? :"#{source}_failure" : :failure).tap do |key|
        StatsD.increment(STATSD_NAMES[key])
      end
      Sentry.capture_exception(e)
      @valid_flag = false
    end

    def sources = SOURCES

    def team_sensitive(profile:, info:, address:, awards: [], pending_documents: [])
      return false unless load_profile(profile)

      load_info(info)
      load_address(address)
      load_awards(awards)
      load_pending_documents(pending_documents)
      true
    end

    def tims_feed(profile:, pending_document:)
      return false unless load_profile(profile)

      load_pending_document(pending_document)
      true
    end

    def bdn_feed(profile:, info:, address:, awards: [])
      return false unless load_profile(profile)

      load_info(info)
      load_address(address)
      load_awards(awards)
      true
    end

    def load_profile(attributes)
      attributes || {} => {ssn:, file_number:} # this shouldn't throw NoMatchingPatternKeyError

      user_profile, conflict, attribute_name =
        UserProfile
        .produce(attributes)
        .values_at(:user_profile, :conflict, :attribute_name)

      if user_profile.new_record? && source == :tims_feed
        raise UserProfileNotFound
      elsif conflict == true && source == :tims_feed
        raise UserProfileConflict
      elsif conflict == true
        message =
          format(
            'Updated conflict for %<attribute_name>s from BDN feed line: %<locator>s',
            attribute_name:, locator:
          )
        Rails.logger.info message
      end

      user_profile.save!
      @user_profile = user_profile
    end

    def load_info(attributes)
      bdn_clone_line = locator
      attributes_final = attributes.merge(bdn_clone:, bdn_clone_line:)
      @user_info = user_profile.user_infos.create!(attributes_final)
    end

    def load_address(attributes)
      user_info.address_changes.create!(attributes)
    end

    def load_awards(awards)
      awards&.each do |attributes|
        user_info.awards.create!(attributes)
      end
    end

    def load_pending_document(attributes)
      user_profile.pending_documents.create!(attributes)
    end

    def load_pending_documents(pending_documents)
      pending_documents.each do |attributes|
        user_profile.pending_documents.create!(attributes)
      end
    end

    public

    def valid?
      @valid_flag
    end
  end
end
