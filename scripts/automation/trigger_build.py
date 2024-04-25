import argparse
import sys
import time
import json

import requests
from request_wrapper import BUILDS_QUEUE_ROOT, BUILDS_ROOT, RequestWrapper


def parse_arguments():
    """
    Parse the arguments with which this script was called through
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--branch_name",
        type=str,
        required=True,
        help="The branch name.",
    )

    parser.add_argument(
        "--build_config_id",
        type=str,
        required=True,
        help="The id of the build configuration to trigger.",
    )

    # parser.add_argument(
    #     "--tag",
    #     type=str,
    #     required=True,
    #     help="The tag to pin the build of the specified artifact with.",
    # )

    parser.add_argument(
        "--refresh_interval",
        "-f",
        type=int,
        required=True,
        help="Refresh interval in seconds used to check the status of the triggered build",
    )
    parser.add_argument(
        "--teamcity_access_token",
        type=argparse.FileType("r"),
        required=True,
        help="The TeamCity access token to authenticate with.",
    )

    return parser.parse_args()


def trigger_build(
    branch_name: str,
    build_config_id: str,
    request: RequestWrapper,
) -> int:

    # setup payload for triggering the build
    build_trigger_json = {
        "buildType": {"id": build_config_id},
        "branchName": branch_name,
    }

    # trigger the build
    response = request.post(BUILDS_QUEUE_ROOT, build_trigger_json)

    # Check if the build was successfully triggered
    if response.status_code == 200:
        print("Build triggered.")
    else:
        print(f"Failed to trigger build (Status code: {response.status_code})")
        return False

    return response.json()["id"]


def wait_for_build(
    build_id: int,
    refresh_interval: int,
    request: RequestWrapper,
) -> bool:

    # construct the url for checking the build state and status
    build_url = f"{BUILDS_ROOT}/{build_id}"

    # Poll for the build state until it's finished then check if it was successful
    print(f"Waiting for build with id {build_id}..")
    while True:
        response = request.get(build_url)
        json_content = response.json()
        # Check if the build is finished
        if json_content["state"] == "finished":
            print("Build finished.")
            # Check if the build was successful
            if json_content["status"] == "SUCCESS":
                print("Build succeeded.")
                return True
            else:
                print("Build failed.")
                return False

        # Wait for refresh_interval seconds before checking again
        time.sleep(refresh_interval)


def get_dependent_builds(build_id, request):
    # Construct the URL for retrieving dependent builds
    url = f"{BUILDS_ROOT}?locator=snapshotDependency:(from:(id:{build_id}))"

    # Make an HTTP GET request to retrieve dependent builds
    response = request.get(url)

    # Check if the request was successful
    if response.status_code == 200:
        return response.json()["build"]
    else:
        print(
            f"Failed to retrieve dependent builds (Status code: {response.status_code})"
        )
        return None


def wait_for_dependent_builds(trigger_build_id, refresh_interval, request):
    # Poll for the status of dependent builds
    delay = 10 * refresh_interval
    time.sleep(delay)
    finished_dependent_build_ids = set()
    while True:
        # Retrieve all dependent builds for the trigger_build_id
        time.sleep(delay)
        dependent_builds = get_dependent_builds(trigger_build_id, request)

        # Check if all dependent builds have finished processing
        all_finished = all(
            build["id"] in finished_dependent_build_ids for build in dependent_builds
        )

        if all_finished:
            print("All dependent builds finished.")
            break

        for build in dependent_builds:
            build_id = build["id"]
            if build_id not in finished_dependent_build_ids:
                config = build["buildTypeId"]
                print(f"Running build config {config} (build id: {build_id})")
                wait_for_build(build_id, refresh_interval, request)
                finished_dependent_build_ids.add(build_id)


def run(
    branch_name: str,
    build_config_id: str,
    refresh_interval: int,
    teamcity_access_token: str,
):
    """
    Runs the script with the specified parameters.

    Args:
        branch_name: str
            The name of the branch.
        build_config_id : str
            The id of the build configuration to trigger.
        refresh_interval : int
            Refresh interval in seconds used to check the status of the triggered build.
        teamcity_access_token : str
            The TeamCity access token to authenticate with.
    """
    request = RequestWrapper(teamcity_access_token)

    trigger_build_id = trigger_build(
        branch_name,
        build_config_id,
        request,
    )

    print(trigger_build_id)

    wait_for_build(
        trigger_build_id,
        refresh_interval,
        request,
    )

    wait_for_dependent_builds(
        trigger_build_id,
        refresh_interval,
        request,
    )


if __name__ == "__main__":
    try:
        args = parse_arguments()
        run(
            args.branch_name,
            args.build_config_id,
            args.refresh_interval,
            args.teamcity_access_token.read(),
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
