# frozen_string_literal: true

require 'vets/type/base'

module Vets
  module Type
    class UTCTime < Base
      def cast(value)
        return nil if value.nil?

        Time.parse(value.to_s).utc
      rescue ArgumentError
        raise TypeError, "#{@name} is not Time parseable"
      end
    end
  end
end
