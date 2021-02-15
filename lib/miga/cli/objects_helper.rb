# @package MiGA
# @license Artistic-2.0

module MiGA::Cli::ObjectsHelper
  ##
  # Get the project defined in the CLI by parameter +name+ and +flag+
  def load_project(name = :project, flag = '-P')
    return @objects[name] unless @objects[name].nil?

    ensure_par(name => flag)
    say "Loading project: #{self[name]}"
    @objects[name] = MiGA::Project.load(self[name])
    raise "Cannot load project: #{self[name]}" if @objects[name].nil?

    @objects[name]
  end

  ##
  # Load the dataset defined in the CLI
  # If +silent=true+, it allows failures silently
  def load_dataset(silent = false, name = nil)
    if name.nil?
      ensure_par(dataset: '-D')
      name = self[:dataset]
    end
    d = load_project.dataset(name)
    raise "Cannot load dataset: #{self[:dataset]}" if !silent && d.nil?

    return d
  end

  ##
  # Load an a project or (if defined) a dataset
  def load_project_or_dataset
    self[:dataset].nil? ? load_project : load_dataset
  end

  ##
  # Load and filter a list of datasets as requested in the CLI
  # If +silent=true+, it allows failures silently
  def load_and_filter_datasets(silent = false)
    return @objects[:filtered_datasets] unless @objects[:filtered_datasets].nil?

    say 'Listing datasets'
    ds =
      if !self[:dataset].nil?
        [load_dataset(silent)].compact
      elsif !self[:ds_list].nil?
        File.readlines(self[:ds_list]).map do |i|
          load_dataset(silent, i.chomp)
        end.compact
      else
        load_project.datasets
      end
    k = 0
    n = ds.size
    ds.select! do |d|
      advance('Datasets:', k += 1, n, false)
      o = true
      o &&= (d.ref? == self[:ref]) unless self[:ref].nil?
      o &&= (d.active? == self[:active]) unless self[:active].nil?
      o &&= (self[:multi] ? d.multi? : d.nonmulti?) unless self[:multi].nil?
      unless self[:taxonomy].nil?
        o &&= (!d.metadata[:tax].nil?) && d.metadata[:tax].in?(self[:taxonomy]) 
      end
      o
    end
    say ''
    ds = ds.values_at(self[:dataset_k] - 1) unless self[:dataset_k].nil?
    @objects[:filtered_datasets] = ds
  end

  def load_result
    return @objects[:result] unless @objects[:result].nil?

    ensure_par(result: '-r')
    obj = load_project_or_dataset
    if obj.class.RESULT_DIRS[self[:result]].nil?
      klass = obj.class.to_s.gsub(/.*::/, '')
      raise "Unsupported result for #{klass}: #{self[:result]}"
    end
    r = obj.add_result(self[:result], false)
    if r.nil? && !self[:ignore_result_empty]
      raise "Cannot load result: #{self[:result]}"
    end

    @objects[:result] = r
  end

  def add_metadata(obj, cli = self)
    raise "Unsupported object: #{obj.class}" unless obj.respond_to? :metadata

    (cli[:metadata] || '').split(',').each do |pair|
      (k, v) = pair.split('=')
      if obj.has_option?(k)
        obj.set_option(k, v, true)
      else
        case v
        when 'true';  v = true
        when 'false'; v = false
        when 'nil';   v = nil
        end
        if k == '_step'
          obj.metadata["_try_#{v}"] ||= 0
          obj.metadata["_try_#{v}"]  += 1
        end
        obj.metadata[k] = v
      end
    end
    %i[type name user description comments].each do |k|
      obj.metadata[k] = cli[k] unless cli[k].nil?
    end
    obj.save
    obj
  end
end
