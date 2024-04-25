import re


def is_semantic_version(version_string):
    """
    Check if a string corresponds to a semantic version.

    Args:
    - version_string (str): The string to be checked.

    Returns:
    - bool: True if the string corresponds to a semantic version, False otherwise.
    """
    # Semantic version regex pattern
    pattern = r"^(\d+)\.(\d+)\.(\d+)$"

    # Compile the regex pattern
    regex = re.compile(pattern)

    # Match the version string against the pattern
    match = regex.match(version_string)

    # If match is found and there are 3 groups corresponding to major, minor, and patch versions
    return (match is not None) and (len(match.groups()) == 3)


def check_semantic_version(version: str):
    if not is_semantic_version(version):
        raise Exception(f"{version} is not a valid semantic version")
