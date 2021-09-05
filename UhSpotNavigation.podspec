Pod::Spec.new do |s|

    # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.name = "UhSpotNavigation"
    s.version = '1.0.1'
    s.summary = "Complete turn-by-turn navigation interface for iOS."
  
    s.description  = <<-DESC
    UhSpot's drop in Interface using MapboxCoreNavigation Services
                     DESC
  
    s.homepage = "https://uhspot.com"
    s.documentation_url = "https://docs.mapbox.com/ios/api/navigation/"
  
    # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.license = { :type => "Mapbox Terms of Service", :file => "LICENSE.md" }
  
    # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.author = { "UhSpot" => "mobile@uhspot.com" }
    s.social_media_url = "https://uhspot.com"
  
    # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.ios.deployment_target = "11.0"
  
    # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.source = { :git => "https://github.com/UhSpot/mapbox-navigation-ios.git", :tag => "v#{s.version.to_s}-uhspot" }
  
    # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.source_files = "Sources/MapboxNavigation/**/*.{h,m,swift}"
  
    # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.resources = ['Sources/MapboxNavigation/Resources/*/*', 'Sources/MapboxNavigation/Resources/*']
  
    # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.requires_arc = true
    s.module_name = "UhSpotNavigation"
  
    s.dependency "UhSpotCoreNavigation", "2.0.0-beta.24"
    s.dependency "MapboxMaps", "10.0.0-rc.7"
    s.dependency "Solar-dev", "~> 3.0"
    s.dependency "MapboxSpeech-pre", "2.0.0-alpha.1"
    s.dependency "MapboxMobileEvents", "~> 1.0.0" # Always specify a patch release if pre-v1.0
  
    s.swift_version = "5.0"

    # https://github.com/mapbox/mapbox-navigation-ios/issues/2665
    s.user_target_xcconfig = {
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '$(EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_$(EFFECTIVE_PLATFORM_SUFFIX)__NATIVE_ARCH_64_BIT_$(NATIVE_ARCH_64_BIT)__XCODE_$(XCODE_VERSION_MAJOR))',
      'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200' => 'arm64 arm64e armv7 armv7s armv6 armv8'
    }
    s.pod_target_xcconfig = {
      'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '$(EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_$(EFFECTIVE_PLATFORM_SUFFIX)__NATIVE_ARCH_64_BIT_$(NATIVE_ARCH_64_BIT)__XCODE_$(XCODE_VERSION_MAJOR))',
      'EXCLUDED_ARCHS__EFFECTIVE_PLATFORM_SUFFIX_simulator__NATIVE_ARCH_64_BIT_x86_64__XCODE_1200' => 'arm64 arm64e armv7 armv7s armv6 armv8'
    }
  end