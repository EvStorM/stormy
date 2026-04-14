require 'xcodeproj'

project_path = 'ios/Runner.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 1. 确保 Configuration.storekit 文件在项目树中
storekit_file = 'Configuration.storekit'
existing_file = project.files.find { |f| f.path == storekit_file }

if existing_file.nil?
  puts "Adding #{storekit_file} to Xcode project..."
  project.main_group.new_file(storekit_file)
else
  puts "#{storekit_file} already exists in Xcode project."
end

# 2. 开启 In-App Purchase Capability
puts "Enabling In-App Purchase capability..."
target = project.targets.find { |t| t.name == 'Runner' }
if target
  project.root_object.attributes['TargetAttributes'] ||= {}
  attributes = project.root_object.attributes['TargetAttributes'][target.uuid] ||= {}
  attributes['SystemCapabilities'] ||= {}
  attributes['SystemCapabilities']['com.apple.InAppPurchase'] = { 'enabled' => '1' }
end

project.save
puts "Xcode project successfully updated."
