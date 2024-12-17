# frozen_string_literal: true

require 'zero_silent_failures/monitor'

require 'rails_helper'

RSpec.describe SimpleFormsApi::NotificationCallback do
  let(:klass) { SimpleFormsApi::NotificationCallback }
  let(:notification) do
    OpenStruct.new(
      notification_id: SecureRandom.uuid,
      notification_type: 'email',
      source_location: 'unit-test',
      status: 'delivered',
      status_reason: 'success',
      callback_klass: klass.to_s,
      callback_metadata: {
        notification_type: 'error',
        statsd_tags: {
          'service' => 'simple_forms_api-test', 'function' => 'unit-test'
        }
      }
    )
  end
  let(:callback) { klass.new(notification) }
  let(:monitor_klass) { ZeroSilentFailures::Monitor }
  let(:monitor) { double(monitor_klass) }

  context 'notification_type == email and email_type == error' do
    describe '#on_deliver' do
      it 'records silent failure avoided - confirmed' do
        expect(monitor_klass).to receive(:new).and_return monitor
        expect(monitor).to receive(:log_silent_failure_avoided).with(
          callback.context, email_confirmed: true, call_location: be_a(Logging::CallLocation)
        )

        klass.call(notification)
      end
    end

    describe '#on_permanent_failure' do
      it 'records silent failure' do
        allow(notification).to receive(:status).and_return 'permanent-failure'

        expect(monitor_klass).to receive(:new).and_return monitor
        expect(monitor).to receive(:log_silent_failure).with callback.context, call_location: be_a(Logging::CallLocation)

        klass.call(notification)
      end
    end

    describe '#on_temporary_failure' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'temporary-failure'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end

    describe '#on_other_status' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'other'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end
  end

  context 'notification_type == email and email_type != error' do
    before do
      metadata = {
        notification_type: 'confirmation',
        statsd_tags: {
          service: 'simple_forms_api-test', function: 'unit-test'
        }
      }
      allow(notification).to receive(:callback_metadata).and_return metadata
    end

    describe '#on_deliver' do
      it 'no monitoring' do
        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end

    describe '#on_permanent_failure' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'permanent-failure'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end

    describe '#on_temporary_failure' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'temporary-failure'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end

    describe '#on_other_status' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'other'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end
  end

  context 'notification_type != email' do
    before do
      allow(notification).to receive(:notification_type).and_return 'NOT-AN-EMAIL'
    end

    describe '#on_deliver' do
      it 'no monitoring' do
        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end

    describe '#on_permanent_failure' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'permanent-failure'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end

    describe '#on_temporary_failure' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'temporary-failure'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end

    describe '#on_other_status' do
      it 'no monitoring' do
        allow(notification).to receive(:status).and_return 'other'

        expect(monitor_klass).not_to receive(:new)

        klass.call(notification)
      end
    end
  end
end
