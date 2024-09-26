# frozen_string_literal: true

require 'common/models/redis_store'

module HCA
  class LogEmailDiffJobStatus < Common::RedisStore
    redis_store REDIS_CONFIG[:hca_log_email_diff_job_status][:namespace]
    redis_ttl REDIS_CONFIG[:hca_log_email_diff_job_status][:each_ttl]
    redis_key :user_uuidπ

    attribute :user_uuid
    validates :user_uuid, presence: true

    def self.set_key(user_uuid)
      redis_namespace.set(user_uuid, 't') unless redis_namespace.exists?(user_uuid)
    end
  end
end
