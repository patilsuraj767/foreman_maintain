require 'rubygems'
require 'csv'
require 'find'
require 'shellwords'

module ForemanMaintain
  module Concerns
    module SystemHelpers
      include Logger
      include Concerns::Finders

      def self.included(klass)
        klass.extend(self)
      end

      # class we use for comparing the versions
      class Version < Gem::Version
        def major
          segments[0]
        end

        def minor
          segments[1]
        end

        def build
          segments[2]
        end
      end

      def systemd_installed?
        File.exist?('/usr/bin/systemctl')
      end

      def check_min_version(name, minimal_version)
        check_version(name) do |current_version|
          current_version >= version(minimal_version)
        end
      end

      def check_max_version(name, maximal_version)
        check_version(name) do |current_version|
          version(maximal_version) >= current_version
        end
      end

      def execute?(command, options = {})
        execute(command, options)
        $CHILD_STATUS.success?
      end

      def command_present?(command_name)
        execute?("command -v #{command_name}")
      end

      def execute_runner(command, options = {})
        command_runner = Utils::CommandRunner.new(logger, command, options)
        execution.puts '' if command_runner.interactive? && respond_to?(:execution)
        command_runner.run
        command_runner
      end

      def execute!(command, options = {})
        command_runner = execute_runner(command, options)
        if command_runner.success?
          command_runner.output
        else
          raise command_runner.execution_error
        end
      end

      def execute(command, options = {})
        execute_runner(command, options).output
      end

      def execute_with_status(command, options = {})
        command_runner = execute_runner(command, options)
        [command_runner.exit_status, command_runner.output]
      end

      def file_exists?(filename)
        File.exist?(filename)
      end

      def file_nonzero?(filename)
        File.exist?(filename) && !File.zero?(filename)
      end

      def find_package(name)
        package_manager.find_installed_package(name)
      end

      def hostname
        execute('hostname -f')
      end

      def server?
        find_package('foreman')
      end

      def packages_action(action, packages, options = {})
        options.validate_options!(:assumeyes)
        case action
        when :install
          package_manager.install(packages, :assumeyes => options[:assumeyes])
        when :update
          package_manager.update(packages, :assumeyes => options[:assumeyes])
        when :remove
          package_manager.remove(packages, :assumeyes => options[:assumeyes])
        else
          raise ArgumentError, "Unexpected action #{action} expected #{expected_actions.inspect}"
        end
      end

      def package_version(name)
        # space for extension to support non-rpm distributions
        rpm_version(name)
      end

      def parse_csv(data)
        parsed_data = CSV.parse(data)
        header = parsed_data.first
        parsed_data[1..-1].map do |row|
          Hash[*header.zip(row).flatten(1)]
        end
      end

      def parse_json(json_string)
        JSON.parse(json_string)
      rescue StandardError
        nil
      end

      def rpm_version(name)
        rpm_version = execute(%(rpm -q '#{name}' --queryformat="%{VERSION}"))
        if $CHILD_STATUS.success?
          version(rpm_version)
        end
      end

      def shellescape(string)
        Shellwords.escape(string)
      end

      def version(value)
        Version.new(value)
      end

      def format_shell_args(options = {})
        options.map { |shell_optn, val| " #{shell_optn} '#{shellescape(val)}'" }.join
      end

      def find_symlinks(dir_path)
        cmd = "find '#{dir_path}' -maxdepth 1 -type l"
        result = execute(cmd).strip
        result.split(/\n/)
      end

      def directory_empty?(dir)
        Dir.entries(dir).size <= 2
      end

      def get_lv_info(dir)
        execute("findmnt -n --target #{dir} -o SOURCE,FSTYPE").split
      end

      def create_lv_snapshot(name, block_size, path)
        execute!("lvcreate -n#{name} -L#{block_size} -s #{path}")
      end

      def get_lv_path(lv_name)
        execute("lvs --noheadings -o lv_path -S lv_name=#{lv_name}").strip
      end

      def find_dir_containing_file(directory, target)
        result = nil
        Find.find(directory) do |path|
          result = File.dirname(path) if File.basename(path) == target
        end
        result
      end

      def package_manager
        ForemanMaintain.package_manager
      end

      def yum_repos
        yum_repo_dir = '/etc/yum.repos.d'
        repositories = Dir.entries(yum_repo_dir).map do |repo_file|
          yum_repo_parser(yum_repo_dir + '/' + repo_file) if repo_file.end_with? '.repo'
        end.compact
        @yum_repos ||= repositories.flatten
      end

      def read_yum_file(repo_file)
        lines = File.open(repo_file).readlines.map do |line|
          line.chomp if !line.start_with?('#') && !line.chomp.empty?
        end.compact
        no_section_header = "Yum repo file #{repo_file} contains no section headers."
        raise(RepoConfigSyntaxError, no_section_header) unless yum_repo_header?(lines[0])

        lines
      end

      # rubocop:disable Metrics/MethodLength
      def yum_repo_parser(repo_file)
        repositories = []
        lines = read_yum_file(repo_file)
        repo = {}
        lines.each_with_index do |line, index|
          if yum_repo_header?(line)
            repo = { 'Repo_id' => line[1..-2] }
          else
            parsing_error = "Parsing errors for file #{repo_file}"
            raise(RepoConfigSyntaxError, parsing_error) unless line.include? '='

            param = line.split('=', 2)
            repo.merge!({ param[0].strip => param[1].strip })
          end
          next_line = lines[index + 1]
          if yum_repo_block_end?(next_line)
            repositories << repo
          end
        end
        repositories
      end
      # rubocop:enable Metrics/MethodLength

      def yum_repo_header?(line)
        line.start_with?('[') && line.end_with?(']')
      end

      def yum_repo_block_end?(next_line)
        !next_line || yum_repo_header?(next_line)
      end

      private

      def check_version(name)
        current_version = package_version(name)
        if current_version
          yield current_version
        end
      end
    end
  end
end
