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
  def load_dataset(silent = false)
    return @objects[:dataset] unless @objects[:dataset].nil?
    ensure_par(dataset: '-D')
    @objects[:dataset] = load_project.dataset(self[:dataset])
    if !silent && @objects[:dataset].nil?
      raise "Cannot load dataset: #{self[:dataset]}"
    end
    return @objects[:dataset]
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
    ds = self[:dataset].nil? ?
      load_project.datasets : [load_dataset(silent)].compact
    ds.select! { |d| d.is_ref? == self[:ref] } unless self[:ref].nil?
    ds.select! { |d| d.is_active? == self[:active] } unless self[:active].nil?
    ds.select! do |d|
      self[:multi] ? d.is_multi? : d.is_nonmulti?
    end unless self[:multi].nil?
    ds.select! do |d|
      (not d.metadata[:tax].nil?) && d.metadata[:tax].in?(self[:taxonomy])
    end unless self[:taxonomy].nil?
    ds = ds.values_at(self[:dataset_k]-1) unless self[:dataset_k].nil?
    @objects[:filtered_datasets] = ds
  end

  def load_result
    return @objects[:result] unless @objects[:result].nil?
    ensure_par(result: '-r')
    obj = load_project_or_dataset
    if obj.class.RESULT_DIRS[self[:result]].nil?
      klass = obj.class.to_s.gsub(/.*::/,'')
      raise "Unsupported result for #{klass}: #{self[:result]}"
    end
    r = obj.add_result(self[:result], false)
    raise "Cannot load result: #{self[:result]}" if r.nil?
    @objects[:result] = r
  end

  def add_metadata(obj, cli = self)
    raise "Unsupported object: #{obj.class}" unless obj.respond_to? :metadata
    cli[:metadata].split(',').each do |pair|
      (k,v) = pair.split('=')
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
    end unless cli[:metadata].nil?
    [:type, :name, :user, :description, :comments].each do |k|
      obj.metadata[k] = cli[k] unless cli[k].nil?
    end
    obj
  end
end

