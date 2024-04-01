import json

# TODO: fetch version: -> https://api.github.com/repos/erlang/otp/tags?per_page=100
# github api has rate limt
# prefer use local version file
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
    version_set = get_all_version()
    with open("versions.txt", 'w') as file:
        for version in version_set:
            file.write(version + '\n')