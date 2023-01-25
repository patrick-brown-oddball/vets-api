# frozen_string_literal: true

module Login
  class UserAcceptableVerifiedCredentialUpdater
    def initialize(user_account:)
      @user_account = user_account
    end

    def perform
      return unless user_account&.verified?

      update_user_acceptable_verified_credential
    end

    private

    attr_reader :user_account

    def update_user_acceptable_verified_credential
      user_avc = UserAcceptableVerifiedCredential.find_or_initialize_by(user_account: user_account)
      user_avc.idme_verified_credential_at ||= Time.zone.now if idme_credential.present?
      user_avc.acceptable_verified_credential_at ||= Time.zone.now if logingov_credential.present?
      if user_avc.changed?
        user_avc.save!
        Rails.logger.info('User AVC Updated',
                          { account_id: user_account.id,
                            idme_credential: idme_credential&.idme_uuid,
                            logingov_credential: logingov_credential&.logingov_uuid })
      end
    end

    def idme_credential
      @idme_credential ||= user_verification_array.where.not(idme_uuid: nil).first
    end

    def logingov_credential
      @logingov_credential ||= user_verification_array.where.not(logingov_uuid: nil).first
    end

    def user_verification_array
      @user_verification_array ||= user_account.user_verification
    end
  end
end
