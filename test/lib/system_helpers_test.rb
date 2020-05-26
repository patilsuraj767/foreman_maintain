require 'test_helper'

class MicroSystem
  include ForemanMaintain::Concerns::SystemHelpers
end

module ForemanMaintain
  describe Concerns::SystemHelpers do
    let(:system) { MicroSystem.new }
    let(:repo_dir) { File.join(File.dirname(__FILE__), '../data/yum.repos.d') }

    describe '.find_package' do
      it 'returns nil if package does not exist' do
        PackageManagerTestHelper.assume_package_exist([])
        assert_nil system.find_package('unknown')
      end
    end

    describe 'yum_repo_parser' do
      it 'must respond positively where repo file syntax is correct' do
        result = [{ 'Repo_id' => 'repo-1', 'enabled' => '1', 'name' => 'Dummy Repo 1',
                    'baseurl' => 'http://dummyrepo1.com' },
                  { 'Repo_id' => 'repo-2', 'enabled' => '2', 'name' => 'Dummy Repo 2',
                    'baseurl' => 'http://dummyrepo2.com' }]
        _(system.yum_repo_parser("#{repo_dir}/valid.repo")).must_equal(result)
      end

      it 'error if first line is not repo headers' do
        _(proc { system.yum_repo_parser("#{repo_dir}/invalid_sec_header.repo") }).must_raise(
          RepoConfigSyntaxError
        )
      end

      it 'error if any line other than repo-id contain "="' do
        _(proc { system.yum_repo_parser("#{repo_dir}/invalid_syntax.repo") }).must_raise(
          RepoConfigSyntaxError
        )
      end
    end
  end
end
