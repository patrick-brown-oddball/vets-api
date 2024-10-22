# frozen_string_literal: true

module Vye
  class SundownSweep
    class ClearDeactivatedBdns
      include Sidekiq::Worker

      def perform
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns: starting delete deactivated bdns')
        Vye::CloudTransfer.delete_inactive_bdns
        logger.info('Vye::SundownSweep::ClearDeactivatedBdns: finished delete deactivated bdns')
      end
    end
  end
end
