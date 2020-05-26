module Checks::Repositories
  class CheckNonRhRepository < ForemanMaintain::Check
    metadata do
      label :check_non_redhat_repository
      description "Check whether system don't have any non Red Hat repositories(Eg: EPEL) enabled"
      tags :pre_upgrade
      confine do
        feature(:instance).downstream
      end
    end

    def run
      with_spinner('Checking repositories enabled on the system') do
        assert(!epel_enabled?, 'System is subscribed to non Red Hat repositories(Eg: EPEL)')
      end
    end

    def epel_enabled?
      repositories = yum_repos.select do |repo|
        repo['Repo_id'].include?('epel') || repo['baseurl'].include?('epel') \
        && repo['enabled'] == '1'
      end
      !repositories.empty?
    end
  end
end
