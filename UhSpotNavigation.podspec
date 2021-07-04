Pod::Spec.new do |s|

    # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.name = "UhSpotNavigation"
    s.version = '0.0.10'
    s.summary = "Complete turn-by-turn navigation interface for iOS."
  
    s.description  = <<-DESC
    UhSpot's drop in Interface using MapboxCoreNavigation Services
                     DESC
  
    s.homepage = "https://uhspot.com"
    s.documentation_url = "https://docs.mapbox.com/ios/api/navigation/"
  
    # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.license = { :type => "ISC", :file => "LICENSE.md" }
  
    # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.author = { "UhSpot" => "mobile@uhspot.com" }
    s.social_media_url = "https://uhspot.com"
  
    # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.ios.deployment_target = "10.0"
  
    # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.source = { :git => "https://github.com/UhSpot/mapbox-navigation-ios.git", :tag => "v#{s.version.to_s}-uhspot" }
  
    # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.source_files = "Sources/UhSpotNavigation/**/*.{h,m,swift}"
  
    # ――― Resources ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.resources = ['Sources/UhSpotNavigation/Resources/*/*', 'Sources/UhSpotNavigation/Resources/*']
  
    # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  
    s.requires_arc = true
    s.module_name = "UhSpotNavigation"
  
    s.dependency "MapboxCoreNavigation", "=1.4.0"
    s.dependency "Mapbox-iOS-SDK", "< 6.2.2"
    s.dependency "Solar", "~> 2.1"
    s.dependency "MapboxSpeech", "~> 1.0"
    s.dependency "MapboxMobileEvents", "~> 0.10.2" # Always specify a patch release if pre-v1.0

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
  