import json
import requests

# fetch version: -> https://api.github.com/repos/erlang/otp/tags?per_page=100&sort=pushed
# github api has rate limt: https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repository-tags
# prefer use local version file
def update_all_version_from_github_api():
    all_version = []
    for page in range(1,10):
        url = f"https://api.github.com/repos/erlang/otp/tags?per_page=100&sort=pushed&page={page}"
        response = requests.get(url)
        data = response.json()
        all_version = all_version + data
    if response.status_code != 200:
        print("Failed to fetch data from github api")
        return

    with open("erlang_otp_versions_from_gtihub_api.json", 'w', encoding="utf-8") as file:
        json.dump(all_version, file, indent=4)

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

def get_all_version():
    version_set = set()
    with open("erlang_otp_versions_from_gtihub_api.json", 'r', encoding="utf-8") as file:
        data = json.load(file)
        for item in data:
            if "OTP-" not in item["tarball_url"]:
                continue
            version = item["tarball_url"].split("OTP-")[1]
            version_set.add(version)
    return version_set

if __name__ == "__main__":
    update_all_version_from_github_api()
    versions = list(get_all_version())
    versions.sort(reverse=True)
    # print(versions)
    with open("versions.txt", 'w') as file:
        for version in versions:
            file.write(version + '\n')
    with open("prebuilt_versions.txt", 'w') as file:
        prebuilt_versions = get_all_prebuilt_version_from_bob()
        prebuilt_versions.sort(reverse=True)
        for version in prebuilt_versions:
            file.write(version + '\n')