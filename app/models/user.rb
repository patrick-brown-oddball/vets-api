# frozen_string_literal: true

require 'common/models/base'
require 'common/models/redis_store'
require 'mvi/messages/find_profile_message'
require 'mvi/service'
require 'evss/common_service'
require 'evss/auth_headers'
require 'saml/user'

class User < Common::RedisStore
  include BetaSwitch

  UNALLOCATED_SSN_PREFIX = '796' # most test accounts use this

  # Defined per issue #6042
  ID_CARD_ALLOWED_STATUSES = %w(V1 V3 V6).freeze

  redis_store REDIS_CONFIG['user_store']['namespace']
  redis_ttl REDIS_CONFIG['user_store']['each_ttl']
  redis_key :uuid

  # id.me attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :middle_name
  attribute :last_name
  attribute :gender
  attribute :birth_date
  attribute :zip
  attribute :ssn
  attribute :loa
  # These attributes are fetched by SAML::User in the saml_response payload
  attribute :multifactor, Boolean # used by F/E to decision on whether or not to prompt user to add MFA
  attribute :authn_context # used by F/E to handle various identity related complexities pending refactor
  # FIXME: if MVI were decorated on usr vs delegated to @mvi, then this might not have been necessary.
  attribute :mhv_icn # only needed by B/E not serialized in user_serializer
  attribute :mhv_uuid # this is the cannonical version of MHV Correlation ID, provided by MHV sign-in users

  # vaafi attributes
  attribute :last_signed_in, Common::UTCTime

  # mhv_last_signed_in used to determine whether we need to notify MHV audit logging
  # This is set to Time.now when any MHV session is first created, and nulled, when logout
  attribute :mhv_last_signed_in, Common::UTCTime

  validates :uuid, presence: true
  validates :email, presence: true
  validates :loa, presence: true

  def initialize(attributes = {}, persisted = false)
    undefined = REQ_CLASS_INSTANCE_VARS.select { |class_var| send(class_var).nil? }
    raise NoMethodError, "Required class methods #{undefined.join(', ')} are not defined" if undefined.any?
    super(attributes)
    @persisted = persisted
    run_callbacks :initialize
  end

  # conditionally validate if user is LOA3
  with_options(on: :loa3_user) do |user|
    user.validates :first_name, presence: true
    user.validates :last_name, presence: true
    user.validates :birth_date, presence: true
    user.validates :ssn, presence: true, format: /\A\d{9}\z/
    user.validates :gender, format: /\A(M|F)\z/, allow_blank: true
  end

  # LOA1 no longer just means ID.me LOA1.
  # It could also be DSLogon or MHV NON PREMIUM users who have not yet done ID.me FICAM LOA3.
  # See also lib/saml/user_attributes/dslogon.rb
  # See also lib/saml/user_attributes/mhv
  def loa1?
    loa[:current] == LOA::ONE
  end

  def loa2?
    loa[:current] == LOA::TWO
  end

  # LOA3 no longer just means ID.me FICAM LOA3.
  # It could also be DSLogon or MHV Premium users.
  # It could also be DSLogon or MHV NON PREMIUM users who have done ID.me FICAM LOA3.
  # Additionally, LOA3 does not automatically mean user has opted to have MFA.
  # See also lib/saml/user_attributes/dslogon.rb
  # See also lib/saml/user_attributes/mhv
  def loa3?
    loa[:current] == LOA::THREE
  end

  def can_access_user_profile?
    loa1? || loa2? || loa3?
  end

  # Must be LOA3 and a va patient
  def mhv_account_eligible?
    (MhvAccount::ALL_STATES - [:ineligible]).map(&:to_s).include?(mhv_account_state)
  end

  def mhv_account_state
    return nil unless loa3?
    mhv_account.account_state
  end

  def can_access_evss?
    edipi.present? && ssn.present? && participant_id.present?
  end

  def can_access_appeals?
    loa3? && ssn.present?
  end

  def can_save_partial_forms?
    true
  end

  def can_access_prefill_data?
    true
  end

  def can_prefill_emis?
    beta_enabled?(uuid, FormProfile::EMIS_PREFILL_KEY)
  end

  def can_access_id_card?
    loa3? && edipi.present? &&
      ID_CARD_ALLOWED_STATUSES.include?(veteran_status.title38_status)
  rescue StandardError # Default to false for any veteran_status error
    false
  end

  delegate :birls_id, to: :mvi
  delegate :edipi, to: :mvi
  delegate :icn, to: :mvi
  delegate :participant_id, to: :mvi
  delegate :veteran?, to: :veteran_status

  def mhv_correlation_id
    mhv_uuid || mvi.mhv_correlation_id
  end

  def va_profile
    mvi.profile
  end

  def va_profile_status
    mvi.status
  end

  def mhv_account
    @mhv_account ||= MhvAccount.find_or_initialize_by(user_uuid: uuid)
  end

  def in_progress_forms
    InProgressForm.where(user_uuid: uuid)
  end

  # Re-caches the MVI response. Use in response to any local changes that
  # have been made.
  def recache
    mvi.cache(uuid, mvi.mvi_response)
  end

  %w(veteran_status military_information payment).each do |emis_method|
    define_method(emis_method) do
      emis_model = instance_variable_get(:"@#{emis_method}")
      return emis_model if emis_model.present?

      emis_model = "EMISRedis::#{emis_method.camelize}".constantize.for_user(self)
      instance_variable_set(:"@#{emis_method}", emis_model)
      emis_model
    end
  end

  def identity
    @identity ||= UserIdentity.find(uuid)
  end

  private

  def mvi
    @mvi ||= Mvi.for_user(self)
  end
end
