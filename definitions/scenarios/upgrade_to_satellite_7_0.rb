module ForemanMaintain::Scenarios
  class PrepForUpgrade < ForemanMaintain::Scenario
    metadata do
      description 'Perpare satellite 6.8 for upgrade.'
      manual_detection
      param :satellite_hostname, 'Hostname of satellite 7.0', :required => true

    end
    def compose
      # Add procedure to run installer with no service restarts 
      add_step(Procedures::Installer::Run)
      
      # Procedure to configure smart proxy to know about 7.0’s pulp 3 server
      #add_step(Procedures::Installer::Run)
      
    end

    def set_context_mapping
      args = ['--key1=val1',
        '--key2=val2']
      context.map(:arguments,
                  Procedures::Installer::Run => args)
    end
  end
end