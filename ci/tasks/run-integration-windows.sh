#!/usr/bin/env bash

set -e

: ${AZURE_ENVIRONMENT:?}
: ${AZURE_SUBSCRIPTION_ID:?}
: ${AZURE_TENANT_ID:?}
: ${AZURE_CLIENT_ID:?}
: ${AZURE_CLIENT_SECRET:?}
: ${SSH_PUBLIC_KEY:?}

: ${METADATA_FILE:=environment/metadata}

metadata=$(cat ${METADATA_FILE})

export BOSH_AZURE_ENVIRONMENT=${AZURE_ENVIRONMENT}
export BOSH_AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
export BOSH_AZURE_TENANT_ID=${AZURE_TENANT_ID}
export BOSH_AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
export BOSH_AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
export BOSH_AZURE_LOCATION=$(echo ${metadata} | jq -e --raw-output ".location")
export BOSH_AZURE_DEFAULT_RESOURCE_GROUP_NAME=$(echo ${metadata} | jq -e --raw-output ".default_resource_group_name")
export BOSH_AZURE_ADDITIONAL_RESOURCE_GROUP_NAME=$(echo ${metadata} | jq -e --raw-output ".additional_resource_group_name")
export BOSH_AZURE_STORAGE_ACCOUNT_NAME=$(echo ${metadata} | jq -e --raw-output ".storage_account_name")
export BOSH_AZURE_EXTRA_STORAGE_ACCOUNT_NAME=$(echo ${metadata} | jq -e --raw-output ".extra_storage_account_name")
export BOSH_AZURE_VNET_NAME=$(echo ${metadata} | jq -e --raw-output ".vnet_name")
export BOSH_AZURE_SUBNET_NAME=$(echo ${metadata} | jq -e --raw-output ".subnet_1_name")
export BOSH_AZURE_SECOND_SUBNET_NAME=$(echo ${metadata} | jq -e --raw-output ".subnet_2_name")
export BOSH_AZURE_DEFAULT_SECURITY_GROUP=$(echo ${metadata} | jq -e --raw-output ".default_security_group")
export BOSH_AZURE_PRIMARY_PUBLIC_IP=$(echo ${metadata} | jq -e --raw-output ".public_ip_in_default_rg")
export BOSH_AZURE_SECONDARY_PUBLIC_IP=$(echo ${metadata} | jq -e --raw-output ".public_ip_in_additional_rg")
export BOSH_AZURE_APPLICATION_SECURITY_GROUP=$(echo ${metadata} | jq -e --raw-output ".asg_name")
export BOSH_AZURE_APPLICATION_GATEWAY_NAME=$(echo ${metadata} | jq -e --raw-output ".application_gateway_name")
export BOSH_AZURE_SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY}

az cloud set --name ${AZURE_ENVIRONMENT}
az login --service-principal -u ${AZURE_CLIENT_ID} -p ${AZURE_CLIENT_SECRET} --tenant ${AZURE_TENANT_ID}
az account set -s ${AZURE_SUBSCRIPTION_ID}

source /etc/profile.d/chruby.sh
chruby ${RUBY_VERSION}

export BOSH_AZURE_STEMCELL_ID="bosh-light-stemcell-00000000-0000-0000-0000-0AZURECPICI0"
account_name=${BOSH_AZURE_STORAGE_ACCOUNT_NAME}
account_key=$(az storage account keys list --account-name ${account_name} --resource-group ${BOSH_AZURE_DEFAULT_RESOURCE_GROUP_NAME} | jq '.[0].value' -r)

# Use the light stemcell cloud properties to generate metadata in space-separated key=value pairs
tar -xf $(realpath stemcell/*.tgz) -C /tmp/
stemcell_metadata=$(ruby -r yaml -r json -e '
  data = YAML::load(STDIN.read)
  stemcell_properties = data["cloud_properties"]
  stemcell_properties["hypervisor"]="hyperv"
  metadata=""
  stemcell_properties.each do |key, value|
    if key == "image"
      metadata += "#{key}=#{JSON.dump(value)} "
    else
      metadata += "#{key}=#{value} "
    end
  end
  puts metadata' < /tmp/stemcell.MF)
dd if=/dev/zero of=/tmp/root.vhd bs=1K count=1
az storage blob upload --file /tmp/root.vhd --container-name stemcell --name ${BOSH_AZURE_STEMCELL_ID}.vhd --type page --metadata ${stemcell_metadata} --account-name ${account_name} --account-key ${account_key}
export BOSH_AZURE_WINDOWS_LIGHT_STEMCELL_SKU=$(ruby -r yaml -r json -e '
  data = YAML::load(STDIN.read)
  stemcell_properties = data["cloud_properties"]
  stemcell_properties.each do |key, value|
    if key == "image"
      value.each do |k, v|
        if k == "sku"
          puts v
          break
        end
      end
    end
  end' < /tmp/stemcell.MF)
export BOSH_AZURE_WINDOWS_LIGHT_STEMCELL_VERSION=$(ruby -r yaml -r json -e '
  data = YAML::load(STDIN.read)
  stemcell_properties = data["cloud_properties"]
  stemcell_properties.each do |key, value|
    if key == "image"
      value.each do |k, v|
        if k == "version"
          puts v
          break
        end
      end
    end
  end' < /tmp/stemcell.MF)

# Accept legal terms
image_urn="pivotal:bosh-windows-server:${BOSH_AZURE_WINDOWS_LIGHT_STEMCELL_SKU}:${BOSH_AZURE_WINDOWS_LIGHT_STEMCELL_VERSION}"
echo "Accepting the legal terms of image ${image_urn}"
az vm image accept-terms --urn ${image_urn}

export BOSH_AZURE_USE_MANAGED_DISKS=${AZURE_USE_MANAGED_DISKS}
pushd bosh-cpi-src/src/bosh_azure_cpi > /dev/null
  bundle install

  tags="--tag ~heavy_stemcell"
  export BOSH_AZURE_USE_MANAGED_DISKS=${AZURE_USE_MANAGED_DISKS}
  if [ "${AZURE_USE_MANAGED_DISKS}" == "true" ]; then
    tags+=" --tag ~unmanaged_disks"
  else
    tags+=" --tag ~availability_zone"
  fi
  bundle exec rspec spec/integration/lifecycle_spec.rb ${tags}
popd > /dev/null
