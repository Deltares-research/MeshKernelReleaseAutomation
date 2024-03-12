import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def parse_args() -> Path:
    """
    Parses the arguments with which this script is called
    """

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--dir_packages_props_file",
        type=Path,
        required=True,
        help="Path to the Directory.Packages.Props file.",
    )

    parser.add_argument(
        "--to_versioned_packages",
        type=lambda packages: {
            name: str(version)
            for name, version in (package.split(":") for package in packages.split())
        },
        required=True,
        help="String consisting of space-separated package:version pairs (the number of spaces is not important), \
            e.g. package_1:1.2.3 package_2:4.5.6.789-rc1    package_3:2020.1.2",
    )

    return parser.parse_args()


def version_string_is_valid(version_string: str) -> bool:
    """
    Checks if a version string is valid.
    A valid version string should be formatted as: <major>.<minor>.<patch>.<build>-<modifier>.
    <major>, <minor>, <patch> and <build> must be integers. <modifier> is alphanumeric.
    <build>, -<modifier> or their combination are optional.

    Args:
    - version_string (str): The string to be checked.

    Returns:
    - bool: True if the string corresponds to a semantic version, False otherwise.
    """

    # Valid version regex pattern
    pattern = r"^(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?(?:-(\w+))?$"

    # Compile the regex pattern
    regex = re.compile(pattern)

    # Match the version string against the pattern
    match = regex.match(version_string)

    return match is not None


def check_version_string(version_string: str) -> None:
    """
    Throws if a version string is invalid.

    Args:
    - version_string (str): The string to be checked.
    """

    if not version_string_is_valid(version_string):
        raise Exception(version_string + " is not a valid version string")


def bump_dependencies_versions(
    dir_packages_props_file_path: Path, versioned_packages: dict
):
    """
    Bumps the versions of the specified dependencies. Skips invalid dependencies.

     Args:
    - dir_packages_props_file_path (Path): The path to the Directory.Package.props file.
    - versioned_packages: Space-separated package:version pairs
    """

    # Parse the XML file
    tree = ET.parse(dir_packages_props_file_path)

    # Get the root node
    root = tree.getroot()

    # Look up the packages in Directory.Package.props and set their new versions.
    # Warn if a package is not found.
    for package_name, new_package_version in versioned_packages.items():
        check_version_string(new_package_version)
        xpath_expr = f"./ItemGroup/PackageVersion[@Include='{package_name}']"
        package_version_element = root.find(xpath_expr)
        if package_version_element is not None:
            print(
                "Info: Package {package_name} : {old_package_version} -> {new_package_version}.".format(
                    package_name=package_name,
                    old_package_version=package_version_element.attrib["Version"],
                    new_package_version=new_package_version,
                )
            )
            package_version_element.attrib["Version"] = new_package_version
        else:
            print(
                "Warning: Package {package_name} not found in {file} and will be skipped.".format(
                    package_name=package_name, file=dir_packages_props_file_path
                )
            )

    # Write the modified tree
    tree.write(dir_packages_props_file_path, encoding="utf-8", method="xml")


if __name__ == "__main__":

    try:
        args = parse_args()
        print(type(args.dir_packages_props_file))
        print(type(args.to_versioned_packages))
        bump_dependencies_versions(
            args.dir_packages_props_file, args.to_versioned_packages
        )

        # print(is_valid_version_string("1.2.3"))  # True
        # print(is_valid_version_string("1.2.3.4"))  # True
        # print(is_valid_version_string("1.2.3.4.5"))  # False
        # print(is_valid_version_string("1.2.3-alpha"))  # True
        # print(is_valid_version_string("1.2.3.4-alpha"))  # True
        # print(is_valid_version_string("1.2.3.1234-dev"))  # True
        # print(is_valid_version_string("1.2.3.4-rc1"))  # True
        # print(is_valid_version_string("1.2.3.4.dev"))  # False
        # print(is_valid_version_string("1.2.3.4-123"))  # True

    except Exception as error:
        print("Error:", error, file=sys.stderr)
