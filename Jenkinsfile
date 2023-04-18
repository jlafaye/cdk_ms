import org.cfm.DataConfiguration

node ('data083.vm.cfm.fr') {
   config = new DataConfiguration()

   config.publish.credentialsId = '6115bf53-b38e-4d14-98ea-ecaa385952af'
   config.component.name = 'data-ms-primebrokerage'
   config.component.type = DataConfiguration.Component.Type.BUSINESS
   configuration = platform.create_data_platform_configuration(config)

   apm_builder.run_python_pipeline(configuration)
}
