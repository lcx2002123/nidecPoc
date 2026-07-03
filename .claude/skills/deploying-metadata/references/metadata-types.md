# Metadata Types — Reference and Project Structure

> Last verified: API v66.0 (Spring '26)
> Source: https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_types_list.htm

---

## Common Metadata Types

| package.xml Name | directoryName | suffix | inFolder | Wildcard (`*`) |
|---|---|---|---|---|
| ApexClass | classes | .cls | No | Yes |
| ApexTrigger | triggers | .trigger | No | Yes |
| ApexComponent | components | .component | No | Yes |
| ApexPage | pages | .page | No | Yes |
| AuraDefinitionBundle | aura | (bundle) | No | Yes |
| LightningComponentBundle | lwc | (bundle) | No | Yes |
| CustomObject | objects | .object | No | Yes |
| CustomField | fields | .field | No | No (child of CustomObject) |
| CustomMetadata | customMetadata | .md | No | Yes |
| CustomLabels | labels | .labels | No | Yes |
| CustomTab | tabs | .tab | No | Yes |
| CustomApplication | applications | .app | No | Yes |
| CustomPermission | customPermissions | .customPermission | No | Yes |
| Layout | layouts | .layout | No | Yes |
| CompactLayout | compactLayouts | .compactLayout | No | No (child of CustomObject) |
| FlexiPage | flexipages | .flexipage | No | Yes |
| Flow | flows | .flow | No | Yes |
| Profile | profiles | .profile | No | Yes |
| PermissionSet | permissionsets | .permissionset | No | Yes |
| PermissionSetGroup | permissionsetgroups | .permissionsetgroup | No | Yes |
| StaticResource | staticresources | .resource | No | Yes |
| Report | reports | .report | Yes | No (use folder paths) |
| Dashboard | dashboards | .dashboard | Yes | No (use folder paths) |
| Document | documents | (varies) | Yes | No (use folder paths) |
| EmailTemplate | email | .email | Yes | No (use folder paths) |
| Workflow | workflows | .workflow | No | Yes |
| ValidationRule | validationRules | .validationRule | No | No (child of CustomObject) |
| RecordType | recordTypes | .recordType | No | No (child of CustomObject) |
| ListView | listViews | .listView | No | No (child of CustomObject) |
| QuickAction | quickActions | .quickAction | No | Yes |
| GlobalValueSet | globalValueSets | .globalValueSet | No | Yes |
| StandardValueSet | standardValueSets | .standardValueSet | No | Yes |
| ConnectedApp | connectedApps | .connectedApp | No | Yes |
| RemoteSiteSetting | remoteSiteSettings | .remoteSite | No | Yes |
| NamedCredential | namedCredentials | .namedCredential | No | Yes |
| ExternalDataSource | dataSources | .dataSource | No | Yes |
| SharingRules | sharingRules | .sharingRules | No | No |
| AssignmentRules | assignmentRules | .assignmentRules | No | No |
| ApprovalProcess | approvalProcesses | .approvalProcess | No | Yes |
| ExperienceBundle | experiences | (bundle) | No | Yes |
| PlatformEventChannel | platformEventChannels | .platformEventChannel | No | Yes |
| PathAssistant | pathAssistants | .pathAssistant | No | Yes |

## Bundle Types (No Single Suffix)

| Type | Directory | Contents |
|---|---|---|
| LightningComponentBundle | lwc/`componentName`/ | `.js`, `.html`, `.css`, `.js-meta.xml` |
| AuraDefinitionBundle | aura/`componentName`/ | `.cmp`, `.js`, `.css`, `.design`, `.svg`, `-meta.xml` |
| ExperienceBundle | experiences/`siteName`/ | Multiple config files and directories |

## Wildcard Rules

- **Yes** — `<members>*</members>` retrieves all components of that type.
- **No (child)** — child metadata (CustomField, ValidationRule, RecordType, ListView, CompactLayout) must be qualified: `ObjectName.FieldName`.
- **No (inFolder)** — folder-based types (Report, Dashboard, Document, EmailTemplate) require folder-qualified members: `FolderName` or `FolderName/ReportName`.
- **AssignmentRules / SharingRules** — must specify the object name as the member: `Case`, `Lead`.

---

## Deployment Order (Recommended)

Deploy in this sequence to avoid reference errors:

| Order | Types | Reason |
|---|---|---|
| 1 | CustomObject, CustomField, GlobalValueSet, StandardValueSet, RecordType | Schema must exist before anything references it |
| 2 | CustomMetadata, CustomLabels, CustomPermission, CustomTab | Referenced by code and configuration |
| 3 | ApexClass (non-test) | Business logic depends on schema |
| 4 | ApexTrigger | Triggers depend on classes and schema |
| 5 | Flow, Workflow, ApprovalProcess, AssignmentRules, SharingRules | Automation depends on schema + classes |
| 6 | Layout, CompactLayout, FlexiPage, PathAssistant, QuickAction | UI depends on fields and actions |
| 7 | LightningComponentBundle, AuraDefinitionBundle, ApexPage, ApexComponent, StaticResource | UI components |
| 8 | Profile, PermissionSet, PermissionSetGroup | Access control references all of the above |
| 9 | Report, Dashboard, Document, EmailTemplate | Content depends on schema + access |
| 10 | ConnectedApp, NamedCredential, RemoteSiteSetting, ExternalDataSource | Integration config (often environment-specific) |
| 11 | ApexClass (test), ExperienceBundle | Tests and experiences deployed last |

---

## package.xml Snippet

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
  <!-- Wildcard — retrieves all components of this type -->
  <types>
    <members>*</members>
    <name>ApexClass</name>
  </types>
  <!-- Child metadata — must qualify with parent object -->
  <types>
    <members>Account.MyField__c</members>
    <name>CustomField</name>
  </types>
  <!-- Folder-based type — specify folder name or folder/item -->
  <types>
    <members>MyFolder</members>
    <members>MyFolder/MyReport</members>
    <name>Report</name>
  </types>
  <version>66.0</version>
</Package>
```

---

## Source Format (DX) vs Metadata Format

Two representations of the same metadata — understand the difference before converting.

### Source Format (what lives in your repo)

```
force-app/
  main/
    default/
      classes/
        AccountService.cls
        AccountService.cls-meta.xml
      triggers/
        AccountTrigger.trigger
        AccountTrigger.trigger-meta.xml
      lwc/
        accountCard/
          accountCard.js
          accountCard.html
          accountCard.css
          accountCard.js-meta.xml
      objects/
        Account/
          fields/
            Status__c.field-meta.xml
          recordTypes/
            Enterprise.recordType-meta.xml
          validationRules/
            RequirePhone.validationRule-meta.xml
```

Each component has its own file. Object children (fields, validation rules, record types) are separate files under the object folder.

### Metadata Format (Change Sets / Metadata API)

```
unpackaged/
  classes/
    AccountService.cls
    AccountService.cls-meta.xml
  objects/
    Account.object          ← single file with ALL fields, validation rules, etc.
  package.xml
```

The entire object is a single monolithic XML file. Merging changes from two orgs is difficult in this format.

### Convert Between Formats

```bash
# Metadata format → source format (after retrieving via MDAPI)
sf project convert mdapi --root-dir unpackaged --output-dir force-app

# Source format → metadata format (before deploying via Change Set tooling)
sf project convert source --source-dir force-app --output-dir unpackaged
```

---

## sfdx-project.json Reference

```json
{
    "packageDirectories": [
        {
            "path": "force-app",
            "default": true,
            "package": "MyApp",
            "versionName": "ver 1.0",
            "versionNumber": "1.0.0.NEXT",
            "definitionFile": "config/project-scratch-def.json"
        },
        {
            "path": "force-app-config",
            "default": false
        }
    ],
    "namespace": "",
    "sourceApiVersion": "66.0",
    "sfdcLoginUrl": "https://login.salesforce.com",
    "pushPackageDirectoriesSequentially": false,
    "packageAliases": {
        "MyApp": "0Ho...",
        "MyApp@1.0.0-1": "04t..."
    }
}
```

| Property | Purpose |
|---|---|
| `packageDirectories` | Directories containing Salesforce source |
| `path` | Relative path to source directory |
| `default` | Whether this is the default deploy target |
| `namespace` | Org namespace (empty string for most orgs) |
| `sourceApiVersion` | Metadata API version — update annually to the current release |
| `pushPackageDirectoriesSequentially` | Deploy directories in order (use for cross-directory dependencies) |
| `packageAliases` | Maps package names and version aliases to 0Ho.../04t... IDs |

---

## .forceignore

Controls which files SF CLI ignores during push/pull/deploy/retrieve operations. Syntax mirrors `.gitignore`.

```
# .forceignore

# Profiles — use Permission Sets instead; Profiles are destructive to deploy
**/profiles/**

# Standard Value Sets — org-managed, cannot deploy
**/standardValueSets/**

# Managed Package components — read-only in subscriber orgs
**/force-app/main/default/classes/fflib_*
**/force-app/main/default/classes/NPSP_*

# Experience Cloud templates — large files, rarely need deploying
**/experiences/**

# Reports and Dashboards — manage via UI; not meaningful in source control
**/reports/**
**/dashboards/**

# Translations — only if not actively managing them
**/translations/**
```

---

## Profiles vs Permission Sets

> Deploying a Profile from source **replaces the entire profile definition** in the target org. Any permission that exists in the org but is not in your source file will be silently revoked. This is almost never the intended behavior.

**Recommended approach:** Use Permission Sets (and Permission Set Groups) for all deployable permission management. Add profiles to `.forceignore` to stop tracking them.

```bash
# Stop tracking profiles
echo "**/profiles/**" >> .forceignore

# Deploy permission sets instead
sf project deploy start \
    --metadata "PermissionSet:Sales_Manager_Permissions" \
    --target-org myOrg
```

When profiles cannot be avoided (e.g., System Administrator baseline configuration):

```bash
# Retrieve ONLY that profile, review the diff carefully before deploying
sf project retrieve start \
    --metadata "Profile:Admin" \
    --target-org myOrg
```

---

## Org Comparison

### List Available Metadata

```bash
# List all metadata types the org supports
sf org list metadata-types --target-org myOrg

# List all components of a specific type
sf org list metadata --metadata-type ApexClass --target-org myOrg
sf org list metadata --metadata-type Flow --target-org myOrg
```

### Compare Two Orgs

```bash
# Retrieve the same manifest from both orgs into separate directories
sf project retrieve start \
    --manifest manifest/package.xml \
    --target-org sourceOrg \
    --output-dir /tmp/source-org

sf project retrieve start \
    --manifest manifest/package.xml \
    --target-org targetOrg \
    --output-dir /tmp/target-org

# Diff the results
diff -r /tmp/source-org /tmp/target-org
```

---

## Custom Metadata Type Records

Custom Metadata Type **records** are metadata — deploy them with `sf project deploy`, not `sf data import`.

```xml
<!-- force-app/main/default/customMetadata/Service_Config.Production.md-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Production Config</label>
    <protected>false</protected>
    <values>
        <field>Endpoint_URL__c</field>
        <value xsi:type="xsd:string">https://api.example.com</value>
    </values>
    <values>
        <field>Timeout_Ms__c</field>
        <value xsi:type="xsd:double">10000</value>
    </values>
</CustomMetadata>
```

**Advantages over Custom Settings:**
- Deployable via Metadata API / SFDX (no data import step)
- Available in Flows and formula fields
- No governor limit on reads (cached by the platform)
- Can be included in managed packages
- Environment-specific configs (Sandbox_Config, Production_Config) deploy as a unit with the code that uses them
