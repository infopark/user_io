# frozen_string_literal: true

require_relative "../user_io"

module Infopark
  class UserIO
    module Global
      def user_io
        Infopark::UserIO.global
      end
    end
  end
end
