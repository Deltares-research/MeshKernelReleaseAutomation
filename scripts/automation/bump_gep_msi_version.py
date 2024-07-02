import argparse
import sys
import xml.etree.ElementTree as ET
from abc import ABC, abstractmethod
from pathlib import Path

from versioning import check_semantic_version


def parse_args() -> Path:
    """
    Parse the arguments with which this script is called
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--wix_ui_variables_file",
        type=Path,
        required=True,
        help="Path to the wix UI variables file.",
    )

    parser.add_argument(
        "--wix_proj_file",
        type=Path,
        required=True,
        help="Path to the wix project file.",
    )

    parser.add_argument(
        "--to_release_version",
        type=str,
        required=True,
        help="The release version (same as version of Grid Editor plugin)",
    )

    parser.add_argument(
        "--to_public_release_version",
        type=str,
        required=True,
        help="The public release version (D-HYDRO version).",
    )

    return parser.parse_args()


class ReleaseVersions:
    def __init__(
        self,
        xml_file: Path,
    ):
        self._xml_file = xml_file
        self._tree = self.__parse_xml()
        self._namespace = self.__extract_and_register_namespace()

    def __parse_xml(self) -> ET.ElementTree:
        parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
        return ET.parse(self._xml_file, parser)

    def __extract_and_register_namespace(self) -> str:
        namespace_uri = self._tree.getroot().tag.split("}")[0].strip("{")
        ET.register_namespace("", namespace_uri)
        return {"": namespace_uri}

    @abstractmethod
    def bump_version(self):
        pass

    def _override(self):
        self._tree.write(
            self._xml_file,
            xml_declaration=True,
            encoding="unicode",
            method="xml",
        )


class WiXUIVariableVersions(ReleaseVersions):
    def __init__(
        self,
        wix_ui_variables_file: Path,
        to_release_version: str,
        to_public_release_version: str,
    ):
        super().__init__(wix_ui_variables_file)
        self.to_release_version = to_release_version
        self.to_public_release_version = to_public_release_version
        self.__bump_version()
        self._override()

    def __modify_attribute(
        self,
        attribute: str,
        value: str,
    ) -> None:
        element = self._tree.getroot().find(
            f".//String[@Id='{attribute}']", self._namespace
        )
        if element is not None:
            element.text = value
        else:
            raise Exception(
                f"{type(self).__name__}: Could not find ID {attribute} in {self._xml_file}"
            )

    def __bump_version(self) -> None:
        self.__modify_attribute(
            "ReleaseVersion",
            self.to_release_version,
        )
        self.__modify_attribute(
            "PublicReleaseVersion",
            self.to_public_release_version,
        )


class WiXProjVersions(ReleaseVersions):
    def __init__(
        self,
        wix_proj_file: Path,
        # to_product_version: str,
        to_release_version: str,
    ):
        super().__init__(wix_proj_file)
        # self.to_product_version = to_product_version
        self.to_release_version = to_release_version
        self.__bump_version()
        self._override()

    def __modify_element(
        self,
        element_name: str,
        value: str,
    ) -> None:
        element = self._tree.getroot().find(
            f".//PropertyGroup/{element_name}", self._namespace
        )

        if element is not None:
            element.text = value
        else:
            raise Exception(
                f"{type(self).__name__}: Could not find element {element_name} in {self._xml_file}"
            )

    def __bump_version(self) -> None:
        # self.__modify_element(
        #     "ProductVersion",
        #     self.to_product_version,
        # )
        self.__modify_element(
            "ReleaseVersion",
            self.to_release_version,
        )


if __name__ == "__main__":
    try:
        args = parse_args()
        check_semantic_version(args.to_release_version)

        WiXUIVariableVersions(
            args.wix_ui_variables_file,
            args.to_release_version,
            args.to_public_release_version,
        )

        WiXProjVersions(
            args.wix_proj_file,
            # to_product_version: str,
            args.to_release_version,
        )

    except Exception as error:
        print("Error:", error, file=sys.stderr)
