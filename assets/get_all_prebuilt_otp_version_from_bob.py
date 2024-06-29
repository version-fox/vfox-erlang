import json
import requests

def get_all_prebuilt_version_from_bob():
    # ALLOW_OS_RELEASE = ["ubuntu-14.04", "ubuntu-16.04", "ubuntu-18.04", "ubuntu-20.04", "ubuntu-22.04", "ubuntu-24.04"]
    ALLOW_OS_RELEASE = ["ubuntu-20.04"]
    all_version_info = []
    for release in ALLOW_OS_RELEASE:
        url = f"https://builds.hex.pm/builds/otp/{release}/builds.txt"
        response = requests.get(url)
        all_version_info = response.text.split("\n")
    
    all_prebuilt_versions = []
    for version in all_version_info:
        if version.split(" ")[0]:
            all_prebuilt_versions.append(version.split(" ")[0])
    return all_prebuilt_versions

if __name__ == "__main__":
    versions = get_all_prebuilt_version_from_bob()
    versions.sort(reverse=True)
    print(versions)
    with open("prebuilt_versions.txt", 'w') as file:
        for version in versions:
            file.write(version + '\n')
    