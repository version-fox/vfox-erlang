#!/usr/bin/env python3
"""
Get macOS prebuilt versions list
Fetch all available macOS prebuilt versions from @erlef/otp_builds GitHub repository
"""

import urllib.request
import json

def get_macos_prebuilt_versions():
    """Fetch all available macOS prebuilt versions from erlef/otp_builds"""
    
    # GitHub API URL for releases
    api_url = "https://api.github.com/repos/erlef/otp_builds/releases"
    
    all_versions = []
    page = 1
    
    try:
        while True:
            print(f"Fetching page {page}...")
            url = f"{api_url}?page={page}&per_page=100"
            
            with urllib.request.urlopen(url) as response:
                if response.status != 200:
                    break
                    
                releases = json.loads(response.read().decode())
                if not releases:
                    break
                    
                for release in releases:
                    tag_name = release["tag_name"]
                    assets = release["assets"]
                    
                    # Check if there are macOS related assets
                    has_macos_assets = False
                    for asset in assets:
                        asset_name = asset["name"]
                        # Check if contains macOS related filename patterns
                        if any(pattern in asset_name.lower() for pattern in [
                            "macos", "darwin", "osx", 
                            "aarch64-apple", "x86_64-apple", 
                            "arm64.tar.gz", "amd64.tar.gz"
                        ]):
                            has_macos_assets = True
                            break
                    
                    if has_macos_assets:
                        all_versions.append(tag_name)
                        print(f"Found macOS version: {tag_name}")
            
            page += 1
            # Limit maximum pages to avoid infinite loop
            if page > 20:
                break
                
    except Exception as e:
        print(f"Error fetching data: {e}")
        return []
    
    return all_versions

def main():
    print("Fetching macOS prebuilt versions from erlef/otp_builds...")
    versions = get_macos_prebuilt_versions()
    
    if versions:
        print(f"\nFound {len(versions)} macOS prebuilt versions:")
        
        # Sort by version number (simple string sorting)
        versions.sort(reverse=True)
        
        # Save to file
        with open("macos_prebuilt_versions.txt", "w", encoding="utf-8") as f:
            for version in versions:
                f.write(version + "\n")
                print(version)
        
        print("\nVersions saved to macos_prebuilt_versions.txt")
    else:
        print("No macOS prebuilt versions found.")

if __name__ == "__main__":
    main()
