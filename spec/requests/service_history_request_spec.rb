# frozen_string_literal: true

require 'rails_helper'
require 'support/error_details'

RSpec.describe 'service_history', skip_emis: true do
  include SchemaMatchers
  include ErrorDetails

  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  describe 'GET /v0/profile/service_history' do
    context 'with VA Profile' do
      let(:user) { build :user, :loa3 }

      before do
        sign_in(user)
        Flipper.enable(:profile_get_military_info_from_vaprofile)
      end

      context 'with a 200 response' do
        context 'with one military service episode' do
          it 'matches the service history schema' do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
              get '/v0/profile/service_history'

              expect(response).to have_http_status(:ok)
              expect(response).to match_response_schema('service_history_response')
            end
          end

          it 'matches the service history schema when camel-inflected' do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
              get '/v0/profile/service_history', headers: inflection_header

              expect(response).to have_http_status(:ok)
              expect(response).to match_camelized_response_schema('service_history_response')
            end
          end

          it 'returns a single service history episode' do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200') do
              get '/v0/profile/service_history'

              json = json_body_for(response)
              episode = json.dig('attributes', 'service_history').first

              expect(episode['branch_of_service']).to eq('Army')
              expect(episode['begin_date']).to eq('2002-02-02')
              expect(episode['end_date']).to eq('2008-12-01')
              expect(episode['personnel_category_type_code']).to eq('N')
            end
          end

          it 'returns multiple service history episodes' do
            VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200') do
              get '/v0/profile/service_history'

              json = json_body_for(response)
              episodes = json.dig('attributes', 'service_history')

              expect(episodes.count).to eq(3)
              episodes.each do |e|
                expect(e['branch_of_service']).not_to be_nil
                expect(e['begin_date']).not_to be_nil
                expect(e['end_date']).not_to be_nil
                expect(e['personnel_category_type_code']).not_to be_nil
              end
            end
          end
        end

        context 'when not successful' do
          context 'with a 400 error' do
            it 'returns nil service history' do
              VCR.use_cassette('va_profile/military_personnel/post_read_service_history_400') do
                get '/v0/profile/service_history'

                expect(response.status).to eq(400)
              end
            end
          end
        end
      end
    end

    context 'with EMIS' do
      before { sign_in }

      Flipper.disable(:profile_get_military_info_from_vaprofile)

      context 'with a 200 response' do
        context 'with one military service episode' do
          it 'matches the service history schema' do
            VCR.use_cassette('emis/get_military_service_episodes/valid') do
              get '/v0/profile/service_history'

              expect(response).to have_http_status(:ok)
              expect(response).to match_response_schema('service_history_response')
            end
          end

          it 'matches the service history schema when camel-inflected' do
            VCR.use_cassette('emis/get_military_service_episodes/valid') do
              get '/v0/profile/service_history', headers: inflection_header

              expect(response).to have_http_status(:ok)
              expect(response).to match_camelized_response_schema('service_history_response')
            end
          end

          it 'increments the StatsD service_history presence counter' do
            VCR.use_cassette('emis/get_military_service_episodes/valid') do
              expect do
                get '/v0/profile/service_history'
              end.to trigger_statsd_increment('api.emis.service_history')
            end
          end

          it 'increments the StatsD EDIPI presence counter' do
            VCR.use_cassette('emis/get_military_service_episodes/valid') do
              expect do
                get '/v0/profile/service_history'
              end.to trigger_statsd_increment('api.emis.edipi')
            end
          end
        end

        context 'with multiple military service episodes' do
          it 'matches the service history schema' do
            VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
              get '/v0/profile/service_history'

              expect(response).to have_http_status(:ok)
              expect(response).to match_response_schema('service_history_response')
            end
          end

          it 'matches the service history schema when camel-inflected' do
            VCR.use_cassette('emis/get_military_service_episodes/valid_multiple_episodes') do
              get '/v0/profile/service_history', headers: inflection_header

              expect(response).to have_http_status(:ok)
              expect(response).to match_camelized_response_schema('service_history_response')
            end
          end
        end
      end

      context 'when EMIS does not return the expected response' do
        before do
          allow(EMISRedis::MilitaryInformation).to receive_message_chain(:for_user, :service_history) { nil }
        end

        it 'matches the errors schema', :aggregate_failures do
          get '/v0/profile/service_history'

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_response_schema('errors')
        end

        it 'matches the errors schema when camel-inflected', :aggregate_failures do
          get '/v0/profile/service_history', headers: inflection_header

          expect(response).to have_http_status(:bad_gateway)
          expect(response).to match_camelized_response_schema('errors')
        end

        it 'includes the correct error code' do
          get '/v0/profile/service_history'

          expect(error_details_for(response, key: 'code')).to eq 'EMIS_HIST502'
        end
      end

      context 'when service history is empty' do
        before do
          allow(EMISRedis::MilitaryInformation).to receive_message_chain(:for_user, :service_history) { [] }
        end

        it 'increments the StatsD service_history empty counter' do
          expect do
            get '/v0/profile/service_history'
          end.to trigger_statsd_increment('api.emis.service_history')
        end
      end

      context 'when user does not have an EDIPI present' do
        before do
          allow_any_instance_of(OpenidUser).to receive(:edipi).and_return(nil)
        end

        it 'increments the StatsD EDIPI empty counter' do
          expect do
            get '/v0/profile/service_history'
          end.to trigger_statsd_increment('api.emis.edipi')
        end
      end
    end
  end
end
