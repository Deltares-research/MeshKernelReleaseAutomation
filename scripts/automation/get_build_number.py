import argparse
import sys

from request_wrapper import BUILDS_ROOT, RequestsWrapper


def parse_args():
    """
    Parse the arguments with which this script is called
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--build_config_id",
        type=str,
        required=True,
        help="build configuration ID",
    )

    parser.add_argument(
        "--version",
        type=str,
        required=True,
        help="The version",
    )

    parser.add_argument(
        "--last_successful_build",
        action="store_true",
        help="Switch for getting the number of the last successful build, whether the build is tagged or not.",
    )

    parser.add_argument(
        "--teamcity_access_token",
        type=argparse.FileType("r"),
        required=True,
        help="The TeamCity access token to authenticate with.",
    )

    args = parser.parse_args()

    return args


def get_build_counter(
    build_config_id: str,
    version: str,
    last_successful_build: bool,
    teamcity_access_token: str,
):
    tag = f"v{version}"
    branch_name = f"release/{tag}"
    url = f"{BUILDS_ROOT}?locator=buildType:{build_config_id},branch:{branch_name}"
    if not last_successful_build:
        url = f"{url},tag:{tag}"
    request = RequestsWrapper(teamcity_access_token)
    headers = {"Accept": "application/json"}
    response = request.get(url, headers=headers)
    builds = response.json()["build"]
    if builds:
        build_counter = builds[0]["number"]
        # build number in TC is formatted as: build_counter + short_git_hash
        return build_counter.split("+")[0].strip()
    else:
        raise Exception(
            f"No builds found matching the criteria [buildType: {build_config_id}, branch: {branch_name}, tag: {tag}]."
        )


if __name__ == "__main__":
    try:
        args = parse_args()
        build_counter = get_build_counter(
            args.build_config_id,
            args.version,
            args.last_successful_build,
            args.teamcity_access_token.read(),
        )
        if build_counter:
            print(build_counter)
    except Exception as error:
        print("Error:", error, file=sys.stderr)
