import requests
from typing import Optional, Dict, Union

TEAMCITY_URL = "https://dpcbuild.deltares.nl"
BUILDS_ROOT = f"{TEAMCITY_URL}/app/rest/builds"
# for user/password auth, use
# BUILDS_ROOT = f"{TEAMCITY_URL}/httpAuth/app/rest/builds":
BUILDS_QUEUE_ROOT = f"{TEAMCITY_URL}/app/rest/buildQueue"
DOWNLOADS_ROOT = f"{TEAMCITY_URL}/repository/download"

import requests


import requests
from typing import Optional, Dict, Union


class RequestsWrapper:
    """
    A wrapper class around requests.Session to simplify authenticated HTTP requests.

    Attributes:
    - session (requests.Session): Session object to maintain connection settings and headers.

    Methods:
    - __init__(token: str): Initialize the RequestsWrapper with a token for authentication.
    - _reset_headers(headers: dict): Manages the headers of the requests
    - get(url: str, headers: dict = None, **kwargs) -> requests.Response:
        Perform a GET request.
    - post(url: str, data: dict = None, json: dict = None, headers: dict = None, **kwargs) -> requests.Response:
        Perform a POST request.
    - put(url: str, data: dict = None, headers: dict = None, **kwargs) -> requests.Response:
        Perform a PUT request.
    - delete(url: str, headers: dict = None, **kwargs) -> requests.Response:
        Perform a DELETE request.
    - patch(url: str, data: dict = None, headers: dict = None, **kwargs) -> requests.Response:
        Perform a PATCH request.
    """

    def __init__(
        self,
        token: str,
    ):
        """
        Initialize a RequestsWrapper instance with a token for authentication.

        Args:
        - token (str): The authentication token to be used for API requests.
        """
        self.session = requests.Session()
        self.session.headers.update({"Authorization": f"Bearer {token}"})

    def _reset_headers(
        self,
        headers: Optional[Dict[str, str]],
    ) -> Dict[str, str]:
        """
        Reset the headers preserving only the 'Authorization' key then merge additional headers

        Args:
        - headers (dict or None): Additional headers to merge.

        Returns:
        - dict: Merged headers.
        """
        new_headers = {"Authorization": self.session.headers.get("Authorization")}
        if headers:
            new_headers.update(headers)
        return new_headers

    def get(
        self,
        url: str,
        headers: Optional[Dict[str, str]] = None,
        **kwargs,
    ) -> requests.Response:
        """
        Perform a GET request using the configured session.

        Args:
        - url (str): The URL for the GET request.
        - headers (dict, optional): Additional headers to include in the request.

        Returns:
        - requests.Response: The response object from the GET request.
        """
        headers = self._reset_headers(headers)
        response = self.session.get(url, headers=headers, **kwargs)
        response.raise_for_status()
        return response

    def post(
        self,
        url: str,
        data: Optional[Dict[str, Union[str, int]]] = None,
        json: Optional[Dict[str, Union[str, int]]] = None,
        headers: Optional[Dict[str, str]] = None,
        **kwargs,
    ) -> requests.Response:
        """
        Perform a POST request using the configured session.

        Args:
        - url (str): The URL for the POST request.
        - data (dict, optional): The body data to send with the request.
        - json (dict, optional): JSON data to send with the request.
        - headers (dict, optional): Additional headers to include in the request.

        Returns:
        - requests.Response: The response object from the POST request.
        """
        headers = self._reset_headers(headers)
        response = self.session.post(
            url, data=data, json=json, headers=headers, **kwargs
        )
        response.raise_for_status()
        return response

    def put(
        self,
        url: str,
        data: Optional[Dict[str, Union[str, int]]] = None,
        headers: Optional[Dict[str, str]] = None,
        **kwargs,
    ) -> requests.Response:
        """
        Perform a PUT request using the configured session.

        Args:
        - url (str): The URL for the PUT request.
        - data (dict, optional): The body data to send with the request.
        - headers (dict, optional): Additional headers to include in the request.

        Returns:
        - requests.Response: The response object from the PUT request.
        """
        headers = self._reset_headers(headers)
        response = self.session.put(url, data=data, headers=headers, **kwargs)
        response.raise_for_status()
        return response

    def delete(
        self,
        url: str,
        headers: Optional[Dict[str, str]] = None,
        **kwargs,
    ) -> requests.Response:
        """
        Perform a DELETE request using the configured session.

        Args:
        - url (str): The URL for the DELETE request.
        - headers (dict, optional): Additional headers to include in the request.

        Returns:
        - requests.Response: The response object from the DELETE request.
        """
        headers = self._reset_headers(headers)
        response = self.session.delete(url, headers=headers, **kwargs)
        response.raise_for_status()
        return response

    def patch(
        self,
        url: str,
        data: Optional[Dict[str, Union[str, int]]] = None,
        headers: Optional[Dict[str, str]] = None,
        **kwargs,
    ) -> requests.Response:
        """
        Perform a PATCH request using the configured session.

        Args:
        - url (str): The URL for the PATCH request.
        - data (dict, optional): The body data to send with the request.
        - headers (dict, optional): Additional headers to include in the request.

        Returns:
        - requests.Response: The response object from the PATCH request.
        """
        headers = self._reset_headers(headers)
        response = self.session.patch(url, data=data, headers=headers, **kwargs)
        response.raise_for_status()
        return response
