# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DisabilityCompensationFormsController, type: :controller do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#separation_locations' do
    it 'returns separation locations' do
      VCR.use_cassette('evss/reference_data/get_intake_sites') do
        get(:separation_locations)
        expect(JSON.parse(response.body)['separation_locations'].present?).to eq(true)
      end
    end

    it 'will use the cached response on the second request' do
      VCR.use_cassette('evss/reference_data/get_intake_sites') do
        2.times do
          get(:separation_locations)
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe '#rating_info' do
    context 'retrieve from Lighthouse' do
      before do
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')

        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, instance_of(User))
                                            .and_return(true)
      end

      it 'returns disability rating' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_response') do
          get(:rating_info)
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)['data']['attributes']
          expect(data['user_percent_of_disability']).to eq(100)
          expect(data['source_system']).to eq('Lighthouse')
        end
      end
    end

    context 'retrieve from EVSS' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, instance_of(User))
                                            .and_return(false)
      end

      it 'returns disability rating' do
        VCR.use_cassette('evss/disability_compensation_form/rating_info') do
          get(:rating_info)
          expect(response).to have_http_status(:ok)

          data = JSON.parse(response.body)['data']['attributes']
          expect(data['user_percent_of_disability']).to eq(100)
          expect(data['source_system']).to eq('EVSS')
        end
      end
    end
  end
end
