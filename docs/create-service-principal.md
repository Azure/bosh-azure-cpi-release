# Create a Service Principal - Azure CLI

This topic shows you how to permit a service principal (such as an automated process, application, or service) to access other resources in your subscription.

# 1 Prepare Azure CLI

## 1.1 Install Azure CLI

Install and configure Azure CLI following the documentation [**HERE**](http://azure.microsoft.com/en-us/documentation/articles/xplat-cli/).

**NOTE:**

* If you already have npm / Node.js installed, run `npm install azure-cli -g`
* It is suggested to run Azure CLI using Ubuntu Server 14.04 LTS or Windows 10.
* If you are using Windows, it is suggested that you use **command line** but not PowerShell to run Azure CLI.

<a name="configure_azure_cli"></a>
## 1.2 Configure Azure CLI

### 1.2.1 Set mode to Azure Resource Management

```
azure config mode arm
```

### 1.2.2 Login

```
#Enter your Microsoft account credentials when prompted.
azure login
```

**NOTE:**

* `azure login` requires a work or school account. Never login with your personal account.
* If you do not have a work or school account currently, you can easily create a work or school account with the [**guide**](https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-connect/).

# 2 Create a Service Principal

Azure CPI provisions resources in Azure using the Azure Resource Manager (ARM) APIs. We use a Service Principal account to give Azure CPI the access to proper resources.

## 2.1 Set Default Subscription

1. Check whether you have multiple subscriptions.

  ```
  azure account list --json
  ```

  Sample Output:

  ```
  [
    {
      "id": "12345678-1234-5678-1234-678912345678",
      "name": "Sample Subscription",
      "user": {
        "name": "Sample Account",
        "type": "user"
      },
      "tenantId": "11111111-1234-5678-1234-678912345678",
      "state": "Enabled",
      "isDefault": true,
      "registeredProviders": [],
      "environmentName": "AzureCloud"
    },
    {
      "id": "87654321-1234-5678-1234-678912345678",
      "name": "Sample Subscription1",
      "user": {
        "name": "Sample Account1",
        "type": "user"
      },
      "tenantId": "22222222-1234-5678-1234-678912345678",
      "state": "Enabled",
      "isDefault": false,
      "registeredProviders": [],
      "environmentName": "AzureCloud"
    }
  ]
  ```

  You can get the following values from the output:

  * **SUBSCRIPTION-ID** - the row `id`
  * **TENANT-ID**       - the row `tenantId`

  **NOTE:** If your **TENANT-ID** is not defined, one possibility is that you are using a personal account to log in to your Azure subscription. See [1.2 Configure Azure CLI](#configure_azure_cli) on how to fix this.

2. Ensure your default subscription is set to the one you want to create your service principal.

  ```
  azure account set <SUBSCRIPTION-ID>
  ```

  Example:

  ```
  azure account set 87654321-1234-5678-1234-678912345678
  ```

  Sample Output:

  ```
  info:    Executing command account set
  info:    Setting subscription to "Sample Subscription" with id "87654321-1234-5678-1234-678912345678".
  info:    Changes saved
  info:    account set command OK
  ```

## 2.2 Creating an Azure Active Directory (AAD) application

Create an AAD application with your information.

```
azure ad app create --name <name> --password <password> --home-page <home-page> --identifier-uris <identifier-uris>
```

* name: The display name for the application
* password: The value for the password credential associated with the application that will be valid for one year by default. This is your **CLIENT-SECRET**.
* home-page: The URL to the application homepage. You can use a faked URL here.
* Identifier-uris: The comma-delimitied URIs that identify the application. You can use a faked URL here.

Example:

```
azure ad app create --name "Service Principal for BOSH" --password "password" --home-page "http://BOSHAzureCPI" --identifier-uris "http://BOSHAzureCPI"
```

Sample Output:

```
info:    Executing command ad app create
+ Creating application Service Principal for BOSH
data:    Application Id:          246e4af7-75b5-494a-89b5-363addb9f0fa
data:    Application Object Id:   a4f0d442-af80-4d98-9cba-6bf1459ad1ea
data:    Application Permissions:
data:                             claimValue:  user_impersonation
data:                             description:  Allow the application to access Service Principal for BOSH on behalf of the signed-in user.
data:                             directAccessGrantTypes:
data:                             displayName:  Access Service Principal for BOSH
data:                             impersonationAccessGrantTypes:  impersonated=User, impersonator=Application
data:                             isDisabled:
data:                             origin:  Application
data:                             permissionId:  1a1eb6d1-26ca-47de-abdb-365f54560e55
data:                             resourceScopeType:  Personal
data:                             userConsentDescription:  Allow the applicationto access Service Principal for BOSH on your behalf.
data:                             userConsentDisplayName:  Access Service Principal for BOSH
data:                             lang:
info:    ad app create command OK
```

* `Application Id` is your **CLIENT-ID** you need to create the service principal.

## 2.3 Create a Service Principal

```
azure ad sp create <CLIENT-ID>
```

Example:

```
azure ad sp create 246e4af7-75b5-494a-89b5-363addb9f0fa
```

Sample Output:

```
info:    Executing command ad sp create
+ Creating service principal for application 246e4af7-75b5-494a-89b5-363addb9f0fa
data:    Object Id:               fcf68d7a-262b-42c4-8ef8-6a4856611155
data:    Display Name:            Service Principal for BOSH
data:    Service Principal Names:
data:                             246e4af7-75b5-494a-89b5-363addb9f0fa
data:                             http://BOSHAzureCPI
info:    ad sp create command OK
```

You can get **service-principal-name** from any value of **Service Principal Names** to assign role to your service principal.

## 2.4 Assigning roles to your Service Principal

Now you have a service principal account, you need to grant this account access to proper resource use Azure CLI.

### 2.4.1 Assigning Roles

```
azure role assignment create \
  --spn <service-principal-name> \
  --roleName "Contributor" \
  --subscription <subscription-id>
```

Example:

```
azure role assignment create \
  --spn "http://BOSHAzureCPI" \
  --roleName "Contributor" \
  --subscription 87654321-1234-5678-1234-678912345678
```

You can verify the assignment with the following command:

```
azure role assignment list --spn <service-principal-name>
```

Sample Output from Nov 2nd 2015: 

```
data:    AD Object:
data:      ID:              7a3029f9-1b74-443e-8987-bed5b6f00009
data:      Type:            ServicePrincipal
data:      Display Name:    Service Principal for BOSH
data:      Principal Name:
data:    Scope:             /subscriptions/87654321-1234-5678-1234-678912345678
data:    Role:
data:      Name:            Contributor
data:      Permissions:
data:        Actions:      *
data:        NotActions:   Microsoft.Authorization/*/Write,Microsoft.Authorization/*/Delete
```

Sample Output from Nov 30th 2015:

```
info:    Executing command role assignment list
+ Searching for role assignments
data:    RoleAssignmentId     : /subscriptions/7edbd93a-ce94-44f8-acd1-4bcf9750abc3/providers/Microsoft.Authorization/roleAssignments/be7fae6f-6e6f-43b1-addc-033750dd20a6
data:    RoleDefinitionName   : Contributor
data:    RoleDefinitionId     : b24988ac-6180-42a0-ab88-20f7382dd24c
data:    Scope                : /subscriptions/7edbd93a-ce94-44f8-acd1-4bcf9750abc3
data:    Display Name         : fordtestad
data:    SignInName           :
data:    ObjectId             : 242dc638-dd49-4fe7-aeac-6fb54a4ee1c7
data:    ObjectType           : ServicePrincipal
data:
info:    role assignment list command OK
```
