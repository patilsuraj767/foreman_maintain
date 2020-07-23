module ForemanMaintain
  module Cli
    class PrepUpgradeCommand < Base
      option '--satellite-7-hostname', "HOSTNAME", 'Hostname of satellite 7.0', require: true
      def execute
      require 'pry'
        binding.pry
        run_scenarios_and_exit(
          Scenarios::PrepForUpgrade.new(
            :satellite_hostname => satellite_hostname
          )
        )
      end
    end
  end
end