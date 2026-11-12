module RosterTestHelper
  def roster_snapshot
    RomaRosterSource.saved.deep_dup
  end

  def roster_choices(preview)
    preview.fetch("rows").to_h do |row|
      [ row.fetch("key"), { "action" => PlayerRosterImport.default_action(row), "name" => row.fetch("name") } ]
    end
  end

  def with_method_override(object, method, replacement)
    original = object.method(method)
    private_method = object.singleton_class.private_method_defined?(method)
    object.define_singleton_method(method, replacement)
    yield
  ensure
    object.define_singleton_method(method, original)
    object.singleton_class.send(:private, method) if private_method
  end
end
