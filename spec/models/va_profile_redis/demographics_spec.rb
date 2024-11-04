# frozen_string_literal: true

require 'rails_helper'

describe VAProfileRedis::Demographics do
  let(:user) { build(:user, :loa3) }
  let(:demographics_response) do
    # preferred_name comes in a nested structure
    preferred_name = OpenStruct.new(preferred_name: 'ABBI')
    bio_data = OpenStruct.new(preferred_name: preferred_name, birth_date: '1984-07-04', gender_identity: nil)
    raw_response = OpenStruct.new(status: 200, body: { 'bio' => bio_data })

    VAProfile::Demographics::DemographicResponse.from(raw_response)
  end

  before do
    allow(VAProfile::Configuration::SETTINGS.demographics).to receive(:cache_enabled).and_return(true)
  end

  describe '#response' do
    context 'when the cache is empty' do
      it 'caches and returns the response', :aggregate_failures do
        allow_any_instance_of(VAProfile::Demographics::Service)
          .to receive(:get_demographics).and_return(demographics_response)
        expect_any_instance_of(VAProfile::Demographics::Service).to receive(:get_demographics)
        demographics_store = VAProfileRedis::Demographics.for_user(user)
        expect(demographics_store.response.status).to eq 200
        expect(demographics_store.demographics.preferred_name.text).to eq 'ABBI'
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data', :aggregate_failures do
        store = VAProfileRedis::Demographics.new
        store.cache(user.uuid, demographics_response)
        store.user = user
        store.populate_from_redis

        expect_any_instance_of(VAProfile::Demographics::Service).not_to receive(:get_demographics)
        expect(store.response.status).to eq 200
        expect(store.demographics.preferred_name.text).to eq 'ABBI'
      end
    end
  end
end
