# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HCA::LogEmailDiffJobStatus, type: :model do
  let(:namespace) { REDIS_CONFIG[:hca_log_email_diff_job_status][:namespace] }
  let(:user_uuid) { SecureRandom.uuid }
  let(:full_key) { "#{namespace}:#{user_uuid}" }

  describe '.set_key' do
    subject do
      described_class.set_key(user_uuid)
    end

    context 'when the key does not exist' do
      it 'sets the key in Redis' do
        expect($redis).not_to exist(full_key)

        subject

        expect($redis).to exist(full_key)
        expect($redis.get(full_key)).to eq('t')
      end
    end

    context 'when the key already exists' do
      it 'does not overwrite the existing key' do
        $redis.set(full_key, 'existing_value')
        expect($redis.get(full_key)).to eq('existing_value')
        subject
        expect($redis.get(full_key)).to eq('existing_value')
      end
    end
  end
end
