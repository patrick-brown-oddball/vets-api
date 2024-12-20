# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::SubmissionJob do
  let(:form) { VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json }
  let(:claim) { create(:caregivers_assistance_claim, form:) }
  let(:statsd_key_prefix) { described_class::STATSD_KEY_PREFIX }
  let(:zsf_tags) { described_class::DD_ZSF_TAGS }
  let(:email_address) { 'jane.doe@example.com' }
  let(:form_with_email) do
    data = JSON.parse(VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json)
    data['veteran']['email'] = email_address
    data.to_json
  end

  before do
    allow(VANotify::EmailJob).to receive(:perform_async)
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  it 'has a retry count of 16' do
    expect(described_class.get_sidekiq_options['retry']).to eq(16)
  end

  it 'defines #notify' do
    expect(described_class.new.respond_to?(:notify)).to eq(true)
  end

  it 'requires a parameter for notify' do
    expect { described_class.new.notify }
      .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
  end

  it 'defines retry_limits_for_notification' do
    expect(described_class.new.respond_to?(:retry_limits_for_notification)).to eq(true)
  end

  it 'returns an array of integers from retry_limits_for_notification' do
    expect(described_class.new.retry_limits_for_notification).to eq([1, 10])
  end

  describe '#notify' do
    subject(:notify) { described_class.new.notify(params) }

    context 'retry_count is 0' do
      let(:params) { { 'retry_count' => 0 } }

      it 'increments applications_retried statsd' do
        expect { notify }.to trigger_statsd_increment('api.form1010cg.async.applications_retried')
      end
    end

    context 'retry_count is not 0 or 9' do
      let(:params) { { 'retry_count' => 5 } }

      it 'does not increment applications_retried statsd' do
        expect { notify }.not_to trigger_statsd_increment('api.form1010cg.async.applications_retried')
      end

      it 'does not increment failed_ten_retries statsd' do
        expect do
          notify
        end.not_to trigger_statsd_increment('api.form1010cg.async.failed_ten_retries', tags: ["params:#{params}"])
      end
    end

    context 'retry_count is 9' do
      let(:params) { { 'retry_count' => 9 } }

      it 'increments failed_ten_retries statsd' do
        expect do
          notify
        end.to trigger_statsd_increment('api.form1010cg.async.failed_ten_retries', tags: ["params:#{params}"])
      end
    end
  end

  describe 'when retries are exhausted' do
    after do
      allow(Flipper).to receive(:enabled?).with(:caregiver_use_va_notify_on_submission_failure).and_return(true)
    end

    let(:msg) do
      {
        'args' => [claim.id]
      }
    end

    context 'when the parsed form does not have an email' do
      context 'the send failure email flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver_use_va_notify_on_submission_failure).and_return(true)
        end

        it 'only increments StatsD' do
          described_class.within_sidekiq_retries_exhausted_block(msg) do
            allow(StatsD).to receive(:increment)
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}failed_no_retries_left",
              tags: ["claim_id:#{claim.id}"]
            )
            expect(StatsD).to receive(:increment).with('silent_failure', tags: zsf_tags)
            expect(VANotify::EmailJob).not_to receive(:perform_async)
          end
        end
      end

      context 'the send failure email flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver_use_va_notify_on_submission_failure).and_return(false)
        end

        it 'only increments StatsD' do
          described_class.within_sidekiq_retries_exhausted_block(msg) do
            allow(StatsD).to receive(:increment)
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}failed_no_retries_left",
              tags: ["claim_id:#{claim.id}"]
            )
            expect(StatsD).to receive(:increment).with('silent_failure', tags: zsf_tags)
            expect(VANotify::EmailJob).not_to receive(:perform_async)
          end
        end
      end
    end

    context 'when the parsed form has an email' do
      let(:form) { form_with_email }

      let(:api_key) { Settings.vanotify.services.health_apps_1010.api_key }
      let(:template_id) { Settings.vanotify.services.health_apps_1010.template_id.form1010_cg_failure_email }
      let(:template_params) do
        [
          email_address,
          template_id,
          {
            'salutation' => "Dear #{claim.parsed_form.dig('veteran', 'fullName', 'first')},"
          },
          api_key,
          {
            callback_metadata: {
              notification_type: 'error',
              form_number: claim.form_id,
              statsd_tags: zsf_tags
            }
          }
        ]
      end

      context 'the send failure email flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver_use_va_notify_on_submission_failure).and_return(true)
        end

        it 'increments StatsD and sends the failure email' do
          described_class.within_sidekiq_retries_exhausted_block(msg) do
            allow(StatsD).to receive(:increment)
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}failed_no_retries_left",
              tags: ["claim_id:#{claim.id}"]
            )

            expect(VANotify::EmailJob).to receive(:perform_async).with(*template_params)
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}submission_failure_email_sent"
            )
          end
        end
      end

      context 'the send failure email flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver_use_va_notify_on_submission_failure).and_return(false)
        end

        it 'only increments StatsD' do
          described_class.within_sidekiq_retries_exhausted_block(msg) do
            allow(StatsD).to receive(:increment)
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}failed_no_retries_left",
              tags: ["claim_id:#{claim.id}"]
            )
            expect(VANotify::EmailJob).not_to receive(:perform_async)
          end
        end
      end
    end
  end

  describe '#perform' do
    let(:job) { described_class.new }

    context 'when there is a standarderror' do
      it 'increments statsd except applications_retried' do
        allow_any_instance_of(Form1010cg::Service).to receive(
          :process_claim_v2!
        ).and_raise(StandardError)

        expect(StatsD).to receive(:increment).twice.with('api.form1010cg.async.retries')
        expect(StatsD).not_to receive(:increment).with('api.form1010cg.async.applications_retried')
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry).twice

        # If we're stubbing StatsD, we also have to expect this because of SavedClaim's after_create metrics logging
        expect(StatsD).to receive(:increment).with('saved_claim.create', { tags: ['form_id:10-10CG'] })

        2.times do
          expect do
            job.perform(claim.id)
          end.to raise_error(StandardError)
        end
      end
    end

    context 'when the service throws a record parse error' do
      context 'the send failure email flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver_use_va_notify_on_submission_failure).and_return(true)
        end

        context 'form has email' do
          let(:form) { form_with_email }

          it 'rescues the error, increments statsd, and attempts to send failure email' do
            expect_any_instance_of(Form1010cg::Service).to receive(
              :process_claim_v2!
            ).and_raise(CARMA::Client::MuleSoftClient::RecordParseError.new)

            expect(SavedClaim.exists?(id: claim.id)).to eq(true)

            expect(VANotify::EmailJob).to receive(:perform_async)
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}submission_failure_email_sent"
            )
            expect(StatsD).to receive(:increment).with(
              "#{statsd_key_prefix}record_parse_error",
              tags: ["claim_id:#{claim.id}"]
            )

            job.perform(claim.id)
          end
        end

        context 'form does not have email' do
          it 'rescues the error, increments statsd, and attempts to send failure email' do
            expect_any_instance_of(Form1010cg::Service).to receive(
              :process_claim_v2!
            ).and_raise(CARMA::Client::MuleSoftClient::RecordParseError.new)

            expect do
              job.perform(claim.id)
            end.to trigger_statsd_increment('api.form1010cg.async.record_parse_error', tags: ["claim_id:#{claim.id}"])
              .and trigger_statsd_increment('silent_failure', tags: zsf_tags)

            expect(SavedClaim.exists?(id: claim.id)).to eq(true)
            expect(VANotify::EmailJob).not_to receive(:perform_async)
          end
        end
      end

      context 'the send failure email flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:caregiver_use_va_notify_on_submission_failure).and_return(false)
        end

        it 'rescues the error and increments statsd' do
          expect_any_instance_of(Form1010cg::Service).to receive(
            :process_claim_v2!
          ).and_raise(CARMA::Client::MuleSoftClient::RecordParseError.new)

          expect do
            job.perform(claim.id)
          end.to trigger_statsd_increment('api.form1010cg.async.record_parse_error', tags: ["claim_id:#{claim.id}"])
            .and trigger_statsd_increment('silent_failure', tags: zsf_tags)

          expect(SavedClaim.exists?(id: claim.id)).to eq(true)
          expect(VANotify::EmailJob).not_to receive(:perform_async)
        end
      end
    end

    context 'when claim cant be destroyed' do
      it 'logs the exception to sentry' do
        expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)
        error = StandardError.new
        expect_any_instance_of(SavedClaim::CaregiversAssistanceClaim).to receive(:destroy!).and_raise(error)

        expect(job).to receive(:log_exception_to_sentry).with(error)
        job.perform(claim.id)
      end
    end

    it 'calls process_claim_v2!' do
      expect_any_instance_of(Form1010cg::Service).to receive(:process_claim_v2!)

      job.perform(claim.id)

      expect(SavedClaim::CaregiversAssistanceClaim.exists?(id: claim.id)).to eq(false)
    end
  end
end
