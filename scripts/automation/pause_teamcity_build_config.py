import argparse
import sys
import requests
import json

from request_wrapper import RequestsWrapper, TEAMCITY_URL


def parse_args():
    """
    Parse the arguments with which this script is called
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--build_config_id",
        type=str,
        required=True,
        help="the build configuration ID to pause",
    )

    action_group = parser.add_mutually_exclusive_group(required=True)

    action_group.add_argument(
        "--pause",
        action="store_true",
        help="Switch for pausing the build configuration",
    )

    action_group.add_argument(
        "--resume",
        action="store_false",
        help="Switch for resuming the build configuration",
    )

    parser.add_argument(
        "--teamcity_access_token",
        type=argparse.FileType("r"),
        required=True,
        help="The TeamCity access token to authenticate with.",
    )

    return parser.parse_args()


def pause_build_config(
    build_config_id: str,
    pause: bool,
    teamcity_access_token: str,
) -> None:
    """
    Pauses a TeamCity build configuration.

    Args:
    - build_config_id (str): The ID of the build configuration to pause or resume
    - pause (bool): pauses the build configuration if true, resumes it otherwise
    - teamcity_access_token (str): TeamCity access token
    """
    request = RequestsWrapper(teamcity_access_token)
    url = f"{TEAMCITY_URL}/app/rest/buildTypes/id:{build_config_id}/paused"
    headers = {"Content-Type": "text/plain"}
    do_pause = "true" if pause else "false"
    request.put(url, headers=headers, data=do_pause)
    action = "paused" if pause else "resumed"
    print(f"Build configuration {build_config_id} {action} successfully.")


if __name__ == "__main__":
    try:
        args = parse_args()

        build_counter = pause_build_config(
            args.build_config_id,
            args.pause,
            args.teamcity_access_token.read(),
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
