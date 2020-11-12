from cumulusci.tasks.salesforce import BaseSalesforceApiTask
from cumulusci.core.exceptions import TaskOptionsError
from cumulusci.core.utils import process_bool_arg

from simple_salesforce.exceptions import SalesforceMalformedRequest


class CheckSObjectsAvailable(BaseSalesforceApiTask):
    api_version = "48.0"

    def _run_task(self):
        self.return_values = {entry["name"] for entry in self.sf.describe()["sobjects"]}

        self.logger.info(
            "Completed sObjects preflight check with result {}".format(
                self.return_values
            )
        )


class CheckSObjectPerms(BaseSalesforceApiTask):
    task_options = {
        "permissions": {
            "description": "The object permissions to check. Each key should be an sObject API name, under which Boolean describe values can be specified, "
            "for example, Account: queryable: True. The output is True if all sObjects and permissions are present and matching the specification.",
            "required": True
        }
    }

    def _init_options(self, kwargs):
        super()._init_options(kwargs)

        if type(self.options["permissions"]) is not dict:
            raise TaskOptionsError("Each sObject should contain a map of permissions to desired values")

        self.permissions = {}
        for sobject, perms in self.options["permissions"].items():
            self.permissions[sobject] = {perm: process_bool_arg(value) for perm, value in perms.items()}

    def _run_task(self):
        describe = {s["name"]: s for s in self.sf.describe()['sobjects']}

        success = True

        for sobject, perms in self.permissions.items():
            if sobject not in describe:
                success = False
                self.logger.warning(f"sObject {sobject} is not present in the describe.")
            else:
                for perm in perms:
                    if perm not in describe[sobject]:
                        success = False
                        self.logger.warning(f"Permission {perm} is not present for sObject {sobject}.")
                    else:
                        if describe[sobject][perm] is not perms[perm]:
                            success = False
                            self.logger.warning(f"Permission {perm} for sObject {sobject} is {describe[sobject][perm]}, not {perms[perm]}.")

        self.return_values = success
        self.logger.info(f"Completing preflight check with result {self.return_values}")


class CheckSObjectOWDs(BaseSalesforceApiTask):
    task_options = {
        "org_wide_defaults": {
            "description": "The Organization-Wide Defaults to check, "
            "organized as a list with each element containing the keys api_name, "
            "internal_sharing_model, and external_sharing_model. NOTE: you must have "
            "External Sharing Model turned on in Sharing Settings to use the latter feature. "
            "Checking External Sharing Model when it is turned off will fail the preflight.",
            "required": True,
        }
    }

    def _init_options(self, kwargs):
        super()._init_options(kwargs)

        if "org_wide_defaults" not in self.options:
            raise TaskOptionsError("org_wide_defaults is a required option")

        if not all("api_name" in entry for entry in self.options["org_wide_defaults"]):
            raise TaskOptionsError("api_name must be included in each entry")

        if not all(
            "internal_sharing_model" in entry or "external_sharing_model" in entry
            for entry in self.options["org_wide_defaults"]
        ):
            raise TaskOptionsError("Each entry must include a sharing model to check.")

        self.owds = {
            entry["api_name"]: (
                entry.get("internal_sharing_model"),
                entry.get("external_sharing_model"),
            )
            for entry in self.options["org_wide_defaults"]
        }

    def _check_owds(self, sobject, result):
        internal = (
            result["InternalSharingModel"] == self.owds[sobject][0]
            if self.owds[sobject][0]
            else True
        )
        external = (
            result["ExternalSharingModel"] == self.owds[sobject][1]
            if self.owds[sobject][1]
            else True
        )
        return internal and external

    def _run_task(self):
        try:
            ext = (
                ", ExternalSharingModel"
                if any(owd[1] is not None for owd in self.owds.values())
                else ""
            )
            object_list = ", ".join(f"'{obj}'" for obj in self.owds.keys())
            results = self.sf.query(
                f"SELECT QualifiedApiName, InternalSharingModel{ext} "
                "FROM EntityDefinition "
                f"WHERE QualifiedApiName IN ({object_list})"
            )["records"]
            self.return_values = all(
                self._check_owds(rec["QualifiedApiName"], rec) for rec in results
            )
        except (IndexError, KeyError, SalesforceMalformedRequest):
            self.return_values = False

        self.logger.info(
            f"Completed Organization-Wide Default preflight with result: {self.return_values}"
        )
