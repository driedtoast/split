module Split
  class Configuration
    BOTS = {
      'Baidu' => 'Chinese spider',
      'Gigabot' => 'Gigabot spider',
      'Googlebot' => 'Google spider',
      'libwww-perl' => 'Perl client-server library loved by script kids',
      'lwp-trivial' => 'Another Perl library loved by script kids',
      'msnbot' => 'Microsoft bot',
      'SiteUptime' => 'Site monitoring services',
      'Slurp' => 'Yahoo spider',
      'WordPress' => 'WordPress spider',
      'ZIBB' => 'ZIBB spider',
      'ZyBorg' => 'Zyborg? Hmmm....'
    }
    attr_accessor :robot_regex
    attr_accessor :ignore_ip_addresses
    attr_accessor :db_failover
    attr_accessor :db_failover_on_db_error
    attr_accessor :db_failover_allow_parameter_override
    attr_accessor :allow_multiple_experiments
    attr_accessor :enabled
    attr_accessor :experiments
    attr_accessor :persistence
    attr_accessor :algorithm

    def disabled?
      !enabled
    end

    def experiment_for(name)
      if normalized_experiments
        normalized_experiments[name]
      end
    end

    def metrics
      return @metrics if defined?(@metrics)
      @metrics = {}
      if self.experiments
        self.experiments.each do |key, value|
          metric_name = value[:metric]
          if metric_name
            @metrics[metric_name] ||= []
            @metrics[metric_name] << Split::Experiment.load_from_configuration(key)
          end
        end
      end
      @metrics
    end
    
    def normalized_experiments
      if @experiments.nil?
        nil
      else
        experiment_config = {}
        @experiments.keys.each do | name |
          experiment_config[name] = {}
        end
        @experiments.each do | experiment_name, settings|
          experiment_config[experiment_name][:variants] = normalize_variants(settings[:variants]) if settings[:variants] 
        end
        experiment_config
      end
    end
    
    
    def normalize_variants(variants)
      given_probability, num_with_probability = variants.inject([0,0]) do |a,v|
        p, n = a
        if v.kind_of?(Hash) && v[:percent]
          [p + v[:percent], n + 1]
        else
          a
        end
      end

      num_without_probability = variants.length - num_with_probability
      unassigned_probability = ((100.0 - given_probability) / num_without_probability / 100.0)

      if num_with_probability.nonzero?
        variants = variants.map do |v|
          if v.kind_of?(Hash) && v[:name] && v[:percent]
            { v[:name] => v[:percent] / 100.0 }
          elsif v.kind_of?(Hash) && v[:name]
            { v[:name] => unassigned_probability }
          else
            { v => unassigned_probability }
          end
        end
        [variants.shift, variants]
      else
        variants = variants.dup
        [variants.shift, variants]
      end
    end

    def initialize
      @robot_regex = /\b(#{BOTS.keys.join('|')})\b/i
      @ignore_ip_addresses = []
      @db_failover = false
      @db_failover_on_db_error = proc{|error|} # e.g. use Rails logger here
      @db_failover_allow_parameter_override = false
      @allow_multiple_experiments = false
      @enabled = true
      @experiments = {}
      @persistence = Split::Persistence::SessionAdapter
      @algorithm = Split::Algorithms::WeightedSample
    end
  end
end
