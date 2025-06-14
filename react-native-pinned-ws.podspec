require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))
folly_compiler_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -DFOLLY_CFG_NO_COROUTINES=1 -Wno-comma -Wno-shorten-64-to-32'

# Define minimum iOS version to match React Native
def min_ios_version_supported
  if defined?(min_ios_version_supported)
    return min_ios_version_supported
  else
    return "12.0"
  end
end

Pod::Spec.new do |s|
  s.name         = "react-native-pinned-ws"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/gamelife/react-native-pinned-ws.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  # Activates the new architecture if available
  new_arch_enabled = ENV['RCT_NEW_ARCH_ENABLED'] == '1'
  folly_version = ENV['FOLLY_VERSION'] || '2024.01.01.00'

  # Core dependency
  s.dependency "React-Core"

  if new_arch_enabled
    # New Architecture (TurboModules + JSI) dependencies and configuration
    s.dependency "React-Codegen"
    s.dependency "RCT-Folly"
    s.dependency "RCTRequired"
    s.dependency "RCTTypeSafety"
    s.dependency "ReactCommon/turbomodule/core"
    
    s.pod_target_xcconfig = {
      "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
      "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER" => "NO",
      "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\" \"$(PODS_ROOT)/RCT-Folly\" \"$(PODS_ROOT)/Headers/Public/React-Codegen/react/renderer/components\" \"$(PODS_ROOT)/Headers/Private/Yoga\"",
      "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) RCT_NEW_ARCH_ENABLED=1",
      "OTHER_CPLUSPLUSFLAGS" => "$(inherited) #{folly_compiler_flags}",
      "USE_HEADERMAP" => "YES"
    }
    
    s.compiler_flags = folly_compiler_flags + ' -DRCT_NEW_ARCH_ENABLED=1'
  else
    # Old Architecture (Legacy) configuration
    s.pod_target_xcconfig = {
      "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
      "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER" => "NO",
      "GCC_PREPROCESSOR_DEFINITIONS" => "$(inherited) RCT_NEW_ARCH_ENABLED=0"
    }
    
    s.compiler_flags = '-DRCT_NEW_ARCH_ENABLED=0'
  end

  # Pre-installation script to display the architecture being used
  s.script_phase = {
    :name => 'Log Architecture Mode',
    :script => "echo 'react-native-pinned-ws: Building with #{new_arch_enabled ? 'New' : 'Old'} Architecture'",
    :execution_position => :before_compile
  }
end
