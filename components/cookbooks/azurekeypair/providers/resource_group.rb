
def whyrun_supported?
  true
end

use_inline_resources

action :create do
  converge_by('Creating Resource Group') do
    rg_manager = AzureBase::ResourceGroupManager.new(@new_resource.node)
    rg_manager.add
  end

  @new_resource.updated_by_last_action(true)
end

action :destroy do
  converge_by('Destroying Resouce Group') do

    cloud_name = @new_resource.node['workorder']['cloud']['ciName']
    if cloud_name = /^azure-.*-wm$/
      rg_manager = AzureBase::ResourceGroupManager.new(@new_resource.node)
      rg_manager.delete
    elsif cloud_name = /^azure-.*-wm-.*$/
      begin
        avset_manager = AzureBase::AvailabilitySetManager.new(@new_resource.node)
        avset_manager.delete
      rescue => e
        if e.message.include?("The Resource 'Microsoft.Compute/availabilitySets/#{avset_manager.as_name}' under resource group '#{avset_manager.rg_name}' was not found")
          OOLog.info("#{avset_manager.as_name} is not found under under resource group #{avset_manager.rg_name}. It might have been deleted already")
        else
          OOLog.fatal("Error destroying #{avset_manager.as_name}: #{e.message}")
        end
      end

      rg_manager = AzureBase::ResourceGroupManager.new(@new_resource.node)
      rg_name = rg_manager.org[0..15] + '-' +
          rg_manager.assembly[0..15] + '-' +
          @new_resource.node['workorder']['payLoad']['Environment'][0]['ciId'].to_s + '-' +
          rg_manager.environment[0..15]  + '-' +
          Utils.abbreviate_location(rg_manager.location)
      rg_manager.rg_name = rg_name

      begin
        resources = rg_manager.list_resources
        if(resources.nil? or resources.length == 0)
          rg_manager.delete
        else
          OOLog.info("#{rg_name} contains resources. not deleting it")
        end
      rescue MsRestAzure::AzureOperationError => e
        error_code = JSON.parse(e.response.body)['error']['code']
        if error_code == 'ResourceGroupNotFound'
          OOLog.info("ResourceGroup #{rg_name} NotFound. It might have been deleted already")
        else
          OOLog.fatal("Error destroying #{rg_name}. #{e.message}")
        end
      rescue => e
        if e.message.include?("Resource group '#{rg_name}' could not be found")
          OOLog.info("Resource group #{rg_name} could not be found. It might have been deleted already")
        else
          OOLog.fatal("Error destroying #{rg_name}: #{e.message}")
        end
      end

    end
  end

  @new_resource.updated_by_last_action(true)
end
