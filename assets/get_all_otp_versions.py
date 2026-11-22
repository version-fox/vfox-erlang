# Copyright 2026 vfox-erlang contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import os

import requests

# GitHub API calls are rate limited per client; the scheduled workflow passes its token so the
# runner gets the higher authenticated limit.
GITHUB_HEADERS = {}
if os.environ.get("GITHUB_TOKEN"):
    GITHUB_HEADERS["Authorization"] = f"Bearer {os.environ['GITHUB_TOKEN']}"
REQUEST_TIMEOUT = 30


# fetch version: -> https://api.github.com/repos/erlang/otp/tags?per_page=100&sort=pushed
# github api has rate limt: https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#list-repository-tags
# prefer use local version file
def update_all_version_from_github_api():
    all_version = []
    for page in range(1, 10):
        url = f"https://api.github.com/repos/erlang/otp/tags?per_page=100&sort=pushed&page={page}"
        response = requests.get(url, headers=GITHUB_HEADERS, timeout=REQUEST_TIMEOUT)
        # Check every page: a failed page is an error body, not a list of tags.
        if response.status_code != 200:
            print(f"Failed to fetch tags from github api (page {page}): HTTP {response.status_code}")
            return
        all_version.extend(response.json())

    with open("erlang_otp_versions_from_gtihub_api.json", "w", encoding="utf-8") as file:
        json.dump(all_version, file, indent=4)


def get_prebuilt_versions_from_bob(release):
    """Returns the build names listed in the builds.txt index of one Ubuntu release."""
    url = f"https://builds.hex.pm/builds/otp/{release}/builds.txt"
    response = requests.get(url, timeout=REQUEST_TIMEOUT)
    # An error page is not an index: fail instead of writing its text as build names.
    if response.status_code != 200:
        raise RuntimeError(f"Failed to fetch {url}: HTTP {response.status_code}")
    names = [line.split(" ")[0] for line in response.text.split("\n")]
    return [name for name in names if name]


def write_version_list(path, versions):
    with open(path, "w") as file:
        for version in sorted(versions, reverse=True):
            file.write(version + "\n")


def write_legacy_prebuilt_versions():
    """Writes prebuilt_versions.txt, the ubuntu-20.04 index, for plugin copies that predate the live index.

    Linux prebuilt searches read the builds.txt index of the chosen release directly (erlang_utils.lua).
    """
    write_version_list("prebuilt_versions.txt", get_prebuilt_versions_from_bob("ubuntu-20.04"))


def get_macos_prebuilt_versions():
    """Fetch all available macOS prebuilt versions from erlef/otp_builds"""

    # GitHub API URL for releases
    api_url = "https://api.github.com/repos/erlef/otp_builds/releases"

    all_versions = []
    page = 1

    try:
        while True:
            print(f"Fetching macOS prebuilt versions page {page}...")
            url = f"{api_url}?page={page}&per_page=100"

            response = requests.get(url, headers=GITHUB_HEADERS, timeout=REQUEST_TIMEOUT)
            if response.status_code != 200:
                break

            releases = response.json()
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
                    if any(
                        pattern in asset_name.lower()
                        for pattern in [
                            "macos",
                            "darwin",
                            "osx",
                            "aarch64-apple",
                            "x86_64-apple",
                            "arm64.tar.gz",
                            "amd64.tar.gz",
                        ]
                    ):
                        has_macos_assets = True
                        break

                if has_macos_assets:
                    # Remove 'OTP-' prefix except for special versions like master-latest
                    processed_version = tag_name
                    if processed_version.startswith("OTP-"):
                        processed_version = processed_version[4:]  # Remove 'OTP-' prefix
                    all_versions.append(processed_version)
                    print(f"Found macOS version: {tag_name} -> {processed_version}")

            page += 1
            # Limit maximum pages to avoid infinite loop
            if page > 20:
                break

    except Exception as e:
        print(f"Error fetching macOS prebuilt data: {e}")
        return []

    return all_versions


def get_all_version():
    version_set = set()
    with open("erlang_otp_versions_from_gtihub_api.json", "r", encoding="utf-8") as file:
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
    with open("versions.txt", "w") as file:
        for version in versions:
            file.write(version + "\n")

    # Generate the Linux list that plugin copies from before the live index read
    write_legacy_prebuilt_versions()

    # Generate prebuilt versions for macOS
    print("\nFetching macOS prebuilt versions...")
    macos_versions = get_macos_prebuilt_versions()
    if macos_versions:
        macos_versions.sort(reverse=True)
        with open("macos_prebuilt_versions.txt", "w", encoding="utf-8") as file:
            for version in macos_versions:
                file.write(version + "\n")
        print(f"Found {len(macos_versions)} macOS prebuilt versions, saved to macos_prebuilt_versions.txt")
    else:
        print("No macOS prebuilt versions found.")
