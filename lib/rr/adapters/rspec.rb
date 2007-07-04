require "spec/mocks"
require "rr"

module RR
  module Adapters
    module Rspec
      include RR::Extensions::DoubleMethods
      def setup_mocks_for_rspec
      end
      def verify_mocks_for_rspec
        RR::Space.instance.verify_doubles
      end
      def teardown_mocks_for_rspec
        RR::Space.instance.reset_doubles
      end
    end
  end
end