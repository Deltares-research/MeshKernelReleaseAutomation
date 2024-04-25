import requests

TEAMCITY_URL = "https://dpcbuild.deltares.nl"
BUILDS_ROOT = f"{TEAMCITY_URL}/app/rest/builds"
# for user/password auth, use
# BUILDS_ROOT = f"{TEAMCITY_URL}/httpAuth/app/rest/builds":
BUILDS_QUEUE_ROOT = f"{TEAMCITY_URL}/app/rest/buildQueue"
DOWNLOADS_ROOT = f"{TEAMCITY_URL}/repository/download"


class RequestWrapper:
    """
    RequestWrapper provides a simple utility wrapper around the requests used within
    the pin_nuget_package.py
    """

    def __init__(self, teamcity_access_token: str):
        """
        Creates a new RequestWrapper with the given parameters.

        Args:
            teamcity_access_token (str): The TeamCity access token to authenticate with.
        """
        self.headers = {
            "Authorization": f"Bearer {teamcity_access_token}",
            "Accept": "application/json",
        }

    def get(self, url: str) -> requests.Response:
        """
        requests.get wrapper (sends a get request).

        Args:
            url (str):  The url to request.

        Returns:
            int: The response.
        """
        response = requests.get(url=url, headers=self.headers)
        response.raise_for_status()
        return response

    def delete(self, url: str) -> requests.Response:
        """
        requests.delete wrapper (sends a delete request).

        Args:
            url (str):  The url to request.

        Returns:
            int: The response.
        """
        response = requests.delete(url=url, headers=self.headers)
        response.raise_for_status()
        return response

    def put_json(self, url: str, json: dict) -> requests.Response:
        """
        requests.put wrapper (sends a put request containing a JSON object).

        Args:
            url (str):  The url to request.

        Returns:
            int: The response.
        """
        response = requests.put(
            url=url,
            headers=self.headers,
            json=json,
        )
        response.raise_for_status()
        return response

    def put(self, url: str) -> requests.Response:
        """
        requests.put wrapper (sends a put request)

        Args:
            url (str):  The url to request.

        Returns:
            int: The response.
        """
        response = requests.put(url=url, headers=self.headers)
        response.raise_for_status()
        return response

    def post(self, url: str, json: dict) -> requests.Response:
        response = requests.post(
            url=url,
            headers=self.headers,
            json=json,
        )
        response.raise_for_status()
        return response
