#!/usr/bin/env ruby

require "psych"
require "yaml"

class ValidationError < StandardError; end

SKILL_KEYS = %w[name description license allowed-tools metadata].freeze
OPENAI_KEYS = %w[interface dependencies policy].freeze
INTERFACE_KEYS = %w[
  display_name short_description icon_small icon_large brand_color default_prompt
].freeze

def reject_duplicate_keys!(node, source, path = "root")
  case node
  when Psych::Nodes::Stream, Psych::Nodes::Document, Psych::Nodes::Sequence
    node.children.each { |child| reject_duplicate_keys!(child, source, path) }
  when Psych::Nodes::Mapping
    seen = {}
    node.children.each_slice(2) do |key_node, value_node|
      key = key_node.is_a?(Psych::Nodes::Scalar) ? key_node.value : key_node.to_s
      raise ValidationError, "duplicate key '#{key}' at #{path} in #{source}" if seen[key]

      seen[key] = true
      reject_duplicate_keys!(value_node, source, "#{path}.#{key}")
    end
  end
end

def parse_yaml!(content, source)
  syntax_tree = Psych.parse_stream(content, source)
  reject_duplicate_keys!(syntax_tree, source)
  YAML.safe_load(content, permitted_classes: [], permitted_symbols: [], aliases: false)
rescue Psych::SyntaxError, Psych::DisallowedClass, Psych::BadAlias => e
  raise ValidationError, "invalid YAML in #{source}: #{e.message}"
end

def assert_hash!(value, source, label)
  return if value.is_a?(Hash)

  raise ValidationError, "#{label} must be a mapping in #{source}"
end

def validate_frontmatter!(skill_file, expected_name)
  content = File.read(skill_file)
  lines = content.lines
  raise ValidationError, "missing opening frontmatter delimiter in #{skill_file}" unless lines.first&.strip == "---"

  closing_index = (1...lines.length).find { |index| lines[index].strip == "---" }
  raise ValidationError, "missing closing frontmatter delimiter in #{skill_file}" unless closing_index

  frontmatter = parse_yaml!(lines[1...closing_index].join, skill_file)
  assert_hash!(frontmatter, skill_file, "frontmatter")

  unknown_keys = frontmatter.keys.map(&:to_s) - SKILL_KEYS
  unless unknown_keys.empty?
    raise ValidationError, "unknown frontmatter keys #{unknown_keys.sort.join(', ')} in #{skill_file}"
  end

  name = frontmatter["name"]
  description = frontmatter["description"]
  raise ValidationError, "name must be a string in #{skill_file}" unless name.is_a?(String)
  raise ValidationError, "description must be a string in #{skill_file}" unless description.is_a?(String)
  raise ValidationError, "skill name '#{name}' must match directory '#{expected_name}'" unless name == expected_name
  unless name.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/) && name.length <= 64
    raise ValidationError, "invalid skill name '#{name}' in #{skill_file}"
  end

  stripped_description = description.strip
  raise ValidationError, "description is empty in #{skill_file}" if stripped_description.empty?
  raise ValidationError, "description exceeds 1024 characters in #{skill_file}" if stripped_description.length > 1024
  if stripped_description.include?("<") || stripped_description.include?(">")
    raise ValidationError, "description contains an angle bracket in #{skill_file}"
  end
  raise ValidationError, "unfinished description in #{skill_file}" if stripped_description.start_with?("[TODO:")

  metadata = frontmatter["metadata"]
  raise ValidationError, "metadata must be a mapping in #{skill_file}" if metadata && !metadata.is_a?(Hash)

  body = lines[(closing_index + 1)..-1].join
  if body.lines.any? { |line| line.strip.match?(/\A\[TODO:[^\]]*\]\z/) }
    raise ValidationError, "unfinished scaffold placeholder in #{skill_file}"
  end

  name
end

def validate_openai_yaml!(skill_dir, skill_name)
  metadata_file = File.join(skill_dir, "agents", "openai.yaml")
  return unless File.file?(metadata_file)

  metadata = parse_yaml!(File.read(metadata_file), metadata_file)
  assert_hash!(metadata, metadata_file, "openai.yaml")

  unknown_keys = metadata.keys.map(&:to_s) - OPENAI_KEYS
  unless unknown_keys.empty?
    raise ValidationError, "unknown openai.yaml keys #{unknown_keys.sort.join(', ')} in #{metadata_file}"
  end

  interface = metadata["interface"]
  assert_hash!(interface, metadata_file, "interface")

  unknown_interface_keys = interface.keys.map(&:to_s) - INTERFACE_KEYS
  unless unknown_interface_keys.empty?
    raise ValidationError, "unknown interface keys #{unknown_interface_keys.sort.join(', ')} in #{metadata_file}"
  end

  %w[display_name short_description default_prompt].each do |key|
    value = interface[key]
    raise ValidationError, "interface.#{key} must be a non-empty string in #{metadata_file}" unless value.is_a?(String) && !value.strip.empty?
  end

  short_description = interface["short_description"].strip
  unless short_description.length.between?(25, 64)
    raise ValidationError, "interface.short_description must contain 25-64 characters in #{metadata_file}"
  end
  unless interface["default_prompt"].include?("$#{skill_name}")
    raise ValidationError, "interface.default_prompt must reference $#{skill_name} in #{metadata_file}"
  end

  %w[icon_small icon_large brand_color].each do |key|
    value = interface[key]
    raise ValidationError, "interface.#{key} must be a string in #{metadata_file}" if value && !value.is_a?(String)
  end
  %w[icon_small icon_large].each do |key|
    value = interface[key]
    raise ValidationError, "interface.#{key} cannot escape the skill directory in #{metadata_file}" if value&.split("/")&.include?("..")
  end
  brand_color = interface["brand_color"]
  if brand_color && !brand_color.match?(/\A#[0-9A-Fa-f]{6}\z/)
    raise ValidationError, "interface.brand_color must be a six-digit hex color in #{metadata_file}"
  end

  dependencies = metadata["dependencies"]
  raise ValidationError, "dependencies must be a mapping in #{metadata_file}" if dependencies && !dependencies.is_a?(Hash)

  policy = metadata["policy"]
  if policy
    assert_hash!(policy, metadata_file, "policy")
    unknown_policy_keys = policy.keys.map(&:to_s) - ["allow_implicit_invocation"]
    unless unknown_policy_keys.empty?
      raise ValidationError, "unknown policy keys #{unknown_policy_keys.sort.join(', ')} in #{metadata_file}"
    end
    allow_implicit = policy["allow_implicit_invocation"]
    unless allow_implicit.nil? || allow_implicit == true || allow_implicit == false
      raise ValidationError, "policy.allow_implicit_invocation must be boolean in #{metadata_file}"
    end
  end
end

skills_dir = File.expand_path(ARGV.fetch(0, File.join(__dir__, "..", ".agents", "skills")))
skill_dirs = Dir.glob(File.join(skills_dir, "*")).select { |path| File.directory?(path) }.sort

if skill_dirs.empty?
  warn "No skills found under #{skills_dir}"
  exit 1
end

errors = []
skill_dirs.each do |skill_dir|
  skill_file = File.join(skill_dir, "SKILL.md")
  begin
    raise ValidationError, "missing SKILL.md in #{skill_dir}" unless File.file?(skill_file)

    skill_name = validate_frontmatter!(skill_file, File.basename(skill_dir))
    validate_openai_yaml!(skill_dir, skill_name)
  rescue ValidationError => e
    errors << e.message
  end
end

unless errors.empty?
  errors.each { |error| warn "FAIL: #{error}" }
  exit 1
end

puts "Validated #{skill_dirs.length} repository skills."

